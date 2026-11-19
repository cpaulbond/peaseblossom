# Empty objects and the collector (bug 28)

On 64-bit LLVM targets, poc 0.14.0's collector freed a reachable object
whose record type has no fields. This document covers the bug, the four
fixes that were tried, the one chosen (an empty object is padded to one
byte, and tracing skips NIL), and what each costs in time and memory.
`PLAN.md`, "Ongoing bug fixing", item 28, has the report. The fixture
`llvm-gc-empty-record` checks the fix.

## The bug

pogeminilib found it (its `PLAN.md`, Phase 4). An abstract `Waiter`, an
extension of an empty record, was held in a global. It was swept anyway,
and a later method call on it crashed. pogeminilib works round it by
giving the record a field.

How `rtl/llvm/GarbageCollectedHeap.Mod` lays out a block:

- A header word holds `size * 4 + inUse * 2 + marked`, and a tag word
  follows it.
- The object's data starts two words into the block.
- Blocks are rounded up to the 16-byte granule.

`BlockBytesFor(0)` is therefore `2 * word` rounded up. On a 64-bit target
that is 16, exactly one granule, with nothing left over. An empty
object's data address, `block + 16`, is then the first byte *after* its
block. That address is one of two things:

- **The next block's start.** `MarkCandidate` gives the address to
  `FindBlock`, which returns the block that contains it: the next block.
  That block is marked, and the empty object's own block stays unmarked
  and is swept. The next block is not kept alive by mistake, since a real
  pointer to it is its own data address, two words further on.
- **The chunk's bump**, when the empty object is the last block
  allocated. `ChunkOf` accepts only addresses below the bump, so nothing
  is marked. The block is swept, and since it is the top of the run,
  `EndRun` lowers the bump below it. The next `NEW` reuses the address.

The reproducer is in `PLAN.md`. After a few collections the empty object's
header reads free, and a method call on it segfaults.

Which targets are affected:

| Target | `word` | Empty block | Data address |
|---|---|---|---|
| LLVM, 64-bit | 8 | 16 bytes, one granule | the block's end: **bug** |
| LLVM, 32-bit | 4 | 8 bytes, rounded to 16 | 8 bytes inside its block |
| VAX/VMS (`rtl/vax`) | 4 | 8 bytes, rounded to 16 | 8 bytes inside its block |

On a 32-bit target the rounding leaves 8 spare bytes, so the data address
stays inside its own block. The VAX collector has the same layout and the
same 16-byte granule. It is unaffected and unchanged.

Any allocation of 0 data bytes hits the bug: a record type with no
fields, an extension of one that adds none, or `SYSTEM.NEW(p, 0)`. An open
array cannot be allocated with no elements, since `NEW` traps a length
that is not positive (exit 7).

## The fixes tried

1. **Padding.** `Allocate` gives a `dataSize` of 0 one byte, so every
   object's data address lies inside its own block. On 64-bit an empty
   block becomes 17 bytes, rounded to 32. Marking is unchanged.
2. **Candidate minus one.** `MarkCandidate` looks up `candidate - 1`
   instead of `candidate`. An object's data starts two words into its
   block, so the byte before any address in an object, its end included,
   lies in the same block. This allocates nothing more. But it changes
   what *every* candidate means, not just an empty object's address. A
   word on the stack that equals a block's start used to be ignored.
   Now it keeps the block *before* that block alive, so conservative
   scanning holds more garbage, and different garbage, than before.
3. **An exact check.** `MarkCandidate` keeps its lookup, and only when a
   candidate is exactly a block's start, or lies just past a chunk's
   bump, it asks `EmptyBlockAt`. That procedure checks whether the block
   before the candidate is an in-use block with a data size of 0 whose
   data address is the candidate. It allocates nothing more, and it
   affects only addresses that are an empty object's. But it adds
   work to every candidate, and with the bump case, every candidate
   outside every chunk is range-tested again (`exact4` below).
4. **The exact check plus a NIL skip.** As 3, but `TraceBlock` no longer
   passes a NIL pointer field to `MarkCandidate` (`exact5`).

The **NIL skip** is independent of the bug. `TraceBlock` passed every
pointer field to `MarkCandidate`, NIL included. That cost a chunk lookup
that always failed, for what is the commonest value in a pointer field.
It is a pure saving, and it goes with whichever fix is chosen.

**Chosen: padding plus the NIL skip.**

- Marking does the same work as before, minus the NIL lookups.
- It does not change how a conservative candidate is read.
- It covers the bump case with no extra code.
- Its one cost is memory: 16 more bytes per empty object, on 64-bit
  only. As measured below, real programs allocate almost no empty
  objects.

The padding is done in `Allocate`, not in `BlockBytesFor`. Sweeping calls
`BlockBytesFor` (through `BlockBytesOf`) for every block. A test there cost
11% more cycles in the allocation benchmark, while one in `Allocate` cost
nothing measurable (see below). As a result, an empty object's header
records a data size of 1, and `Census` reports that 1.

## Performance

All runs were on atla (i9-13900HX), pinned to performance core 4
(`taskset -c 4`), counting user-mode `instructions` and `cycles` with
`perf stat` on the `cpu_core` PMU. Each runtime variant was built from
source against the same `rtl/llvm` copy
(`poc -OC -clear-library-path -clear-import-path -import-path <copy>`).
There were three runs of each, and the instruction counts repeat to within
a few hundred.

Two programs:

- **Mark** is marking alone. It builds a 1M-node binary tree (two pointers
  and a `LONGINT` per node) and calls `Collect` 100 times. Half of its
  pointer fields, the leaves', are NIL.
- **Bench** is allocation and collection. It builds the same tree and
  1,000 empty objects. Then, 30 times, it allocates 200,000 seven-node
  trees and collects.

```
MODULE Mark;
IMPORT Out, GarbageCollectedHeap;
TYPE Node = POINTER TO NodeDesc; NodeDesc = RECORD left, right: Node; v: LONGINT END;
VAR root: Node; k: LONGINT;
PROCEDURE Build(d: INTEGER): Node; VAR n: Node;
BEGIN NEW(n); n.v := d; IF d > 0 THEN n.left := Build(d - 1); n.right := Build(d - 1) END; RETURN n END Build;
BEGIN
  root := Build(19);
  FOR k := 1 TO 100 DO GarbageCollectedHeap.Collect END;
  Out.Int(root.v, 0); Out.Ln
END Mark.

MODULE Bench;
IMPORT Out, GarbageCollectedHeap;
TYPE Node = POINTER TO NodeDesc; NodeDesc = RECORD left, right: Node; v: LONGINT END;
  E = POINTER TO ED; ED = RECORD END;
VAR root: Node; es: ARRAY 1000 OF E; i, k, sum: LONGINT; t: Node;
PROCEDURE Build(d: INTEGER): Node; VAR n: Node;
BEGIN NEW(n); n.v := d; IF d > 0 THEN n.left := Build(d - 1); n.right := Build(d - 1) END; RETURN n END Build;
PROCEDURE Count(n: Node): LONGINT;
BEGIN IF n = NIL THEN RETURN 0 ELSE RETURN 1 + Count(n.left) + Count(n.right) END END Count;
BEGIN
  root := Build(19);
  FOR i := 0 TO LEN(es) - 1 DO NEW(es[i]) END;
  FOR k := 1 TO 30 DO
    FOR i := 1 TO 200000 DO t := Build(2) END;
    GarbageCollectedHeap.Collect
  END;
  sum := Count(root); Out.Int(sum, 0); Out.Ln
END Bench.
```

Results (instructions and cycles in units of 10^9):

| Variant | Mark instr. | Mark cycles | Bench instr. | Bench cycles |
|---|---|---|---|---|
| before the fix (`11884c6`) | 23.91 | 8.9-9.0 | 33.89 | 9.9-10.0 |
| NIL skip alone (not a fix) | 23.28 | 8.6-8.8 | 33.50 | 9.5-9.8 |
| **padding in `Allocate` + NIL skip (chosen)** | **23.28** | **8.8-9.0** | **33.90** | **9.5** |
| padding in `BlockBytesFor` + NIL skip | 23.60 | 8.8-9.0 | 34.24 | 10.6-10.8 |
| exact check (`exact4`) | 27.4 | about 10 | - | - |
| exact check + NIL skip (`exact5`) | 24.9 | 9.3-9.4 | 34.5 | 10.1-10.2 |

Compared with the unfixed collector, the chosen fix:

- runs 2.6% fewer instructions in marking, from the NIL skip, with
  cycles about the same;
- runs the same instructions and about 4% fewer cycles in allocation and
  collection. The test in `Allocate` adds about 0.4 G instructions over
  Bench's 42 million allocations, and the NIL skip saves about as many.

The exact check costs 4-15% in marking, depending on whether the NIL skip
offsets it. Padding in `BlockBytesFor` adds 0.3 G instructions to
Mark and about 10% to Bench's cycles, since sweeping evaluates the test
for every block.

`tools/bench/gc-compare.sh` compared the tree before the fix (`11884c6`,
whose collector is 0.14.0's) with the fix, each with its own Stage 1 poc and with medians of 7 runs. Its
gcbench workload:

| Workload | Tree | Wall | User | Peak MB | Instructions | Cycles |
|---|---|---|---|---|---|---|
| gcbench | 11884c6 | 0.36 s | 0.35 s | 16.4 | 6.90 G | 1.75 G |
| gcbench | fixed | 0.34 s | 0.34 s | 16.1 | 6.86 G | 1.68 G |

The script's poc-ir workload did not run then, because its import path
lacked the VAX back end's directories (`PLAN.md`, "Ongoing bug fixing",
29, since fixed). The same workload was run by hand with the full import
path: each tree's
Stage 1 poc emits the LLVM IR for `11884c6`'s source, 7 timed runs and 3
counted runs per tree. The output was identical.

| Workload | Tree | Wall | User | Peak MB | Instructions | Cycles |
|---|---|---|---|---|---|---|
| poc-ir | 11884c6 | 0.82 s | 0.76 s | 51.4-51.9 | 12.71 G | 3.71 G |
| poc-ir | fixed | 0.81 s | 0.75 s | 51.4-52.1 | 12.71 G | 3.58 G |

## Memory

On 64-bit, padding makes an empty object's block 32 bytes instead of 16.
No other object changes size. On 32-bit targets nothing changes: an empty
block needs 8 bytes and a padded one 9, and both round up to 16.

How many empty objects do programs allocate?

- **poc compiling itself.** A runtime instrumented to count every
  `Allocate` counted poc building `src/driver/Poc.Mod` (all 94 modules).
  It made 984,412 allocations, 88.5 MB of blocks, none of them empty. The
  fix adds 0 bytes, and poc-ir's peak memory above is the same for both
  trees.
- **The Oberon programs under `~/Repos/Oberon`.** A search for record
  types with no fields (`RECORD END`, with or without a base) found 14
  outside test programs. Nearly all are abstract bases that only
  extensions with fields are allocated from: `SyntaxTree.TypeHandleDesc`,
  `Types.ScopeHandleDesc`, `Texts.ElemMsg`, `FormattedInput.Source`,
  pofltk's `FlDraw.AreaDesc` and `ImageSourceDesc`, poDateTime's
  `TimeZones.ZoneDesc`. An extension that adds a field is not empty, and
  padding does not touch it. The likeliest real empty object is a
  `Tasks.MessageDesc` sent bare on a channel as a signal, or a base used
  directly as pogeminilib's `Waiter` was.

So the cost is 16 bytes for each *live* empty object on a 64-bit target.
Even 100,000 of them at once would be 1.6 MB.

## The fixture

`test/conformance/llvm-gc-empty-record` checks both cases:

- **The bump case.** The empty object is the last one allocated, from
  deep in the stack. The stack is overwritten and a collection run. The
  next `NEW` must not reuse its address.
- **The next-block case.** 100 empty objects are each followed by a
  one-field object, then collected. None may read free.

It then calls a method on one of each. Against 0.14.0's runtime it prints
"yes" and 100, and then segfaults.

# The collector under valgrind

`PLAN.md`, "Ongoing library enhancements" 13 (the user, 2026-11-18):
memcheck reported the collector's stack scan in programs that were
otherwise clean. Under valgrind, poc's collector now reads each word of a
stack through a copy that memcheck takes for defined
(`rtl/llvm/GarbageCollectedHeap.c`), so memcheck reports nothing the scan
reads and still reports every other use of an undefined value. Programs
no longer need suppressions for the collector.

## What was reported

The collector scans each stack conservatively, from the stack pointer to
the stack's base: the main stack in `MarkFromStack`, a suspended
coroutine's in `MarkRange`, which `Coroutines`' scanner calls. A word
that holds a heap block's address keeps that block. memcheck takes a
frame's words for undefined from when the frame is made until the program
writes them, so two kinds of report came from the scan:

- **The test of a word.** `MarkCandidate` compares each word with the
  heap's bounds and looks it up in a chunk's start map, branching on
  the result. Every unwritten word in range gives "Conditional jump or
  move depends on uninitialised value(s)" or "Use of uninitialised value
  of size 8" there. The projects' suppression files (`test/poc-gc.supp`
  in pofltk, pogeminilib, polibfyaml, polibtls, posockets and pounix,
  `test/valgrind.supp` in poDB) suppress these by `MarkCandidate` as the
  top frame.
- **The marking that follows.** An unwritten word can still hold what an
  earlier call left there, and if that is the address of a block, the
  block is pushed on the mark stack and traced, all of it through a
  value memcheck takes for undefined. At `-opt 2` `MarkCandidate` and
  `TraceBlock` are inlined, so these reports name
  `GarbageCollectedHeap.DrainMarkStack`, which `poc-gc.supp` did not
  cover: posockets' `TestFileServer` had a suppression file of its own
  for them (`test/TestFileServer.supp`).

poc zeroes every Oberon variable, locals included (`AGENTS.md`,
"Pointers, `NEW` and the runtime"), so the unwritten words are not
variables. They are LLVM's: spill slots a function writes on some paths
only, slots of a local that SROA took apart, and alignment holes, and C's
own frames when a callback calls back into Oberon. Nothing in the
program reads them, and a stale address in one keeps at most a block the
program no longer needs, as with any conservative collector.

## pogeminilib's "padding" was this

pogeminilib (its `AGENTS.md` and `PLAN.md`, Phase 2) took the
`DrainMarkStack` report for a real one: a record copied whole from the
stack into the heap carries its uninitialised padding, and its
`test/TestText.Mod` copied the record field by field to avoid it. That is
not what happened. With `--track-origins=yes` the origin is a stack
allocation in `Take`, but SROA had already taken the local record apart,
so there was no record and no padding: the words were `Take`'s spill
slots. Copying field by field changed `Take`'s frame and so which slots
held stale addresses. With the whole-record copy restored and no
suppressions, `TestText` gives 700,877 errors with the old collector and
none with this one.

So the projects' reason for keeping `DrainMarkStack` out of their
`poc-gc.supp` does not hold. With this change they need no suppressions
for the collector at all.

## The change

`GarbageCollectedHeap.c`, the module's part in C (the `<M>.c` rule, as
`Coroutines.c`), has two functions:

- `UnderValgrind`: valgrind.h's `RUNNING_ON_VALGRIND`. `Collect` asks it
  once, at its first call, and keeps the answer.
- `DefinedWord(address)`: copies the word at `address` into a local and
  tells memcheck that the local is defined (`memcheck.h`'s
  `VALGRIND_MAKE_MEM_DEFINED`), then returns it.

When the program runs under valgrind, `MarkFromStack` and `MarkRange` scan
through `MarkRangeDefined`, which reads each word with `DefinedWord`;
otherwise they read the words themselves, as before. Only the copy is
marked defined, so what memcheck knows about the stack does not change,
and a later read by the program of a word it never wrote is still
reported. The heap is not touched: `TraceBlock` reads a block's pointer
fields directly, and memcheck still reports an undefined value the program
stored there.

`rtl/llvm/memcheck.h` is valgrind 3.27.1's, unchanged, beside its
`valgrind.h` (`doc/developer/coroutines-under-valgrind.md` says why the
headers are copied rather than found on the machine). memcheck.h includes
`"valgrind.h"` and has the same BSD-style licence for itself alone; the
packages' copyright records name both.

### Why not turn error reporting off

The first idea in `PLAN.md` was to bracket a collection with
`VALGRIND_DISABLE_ERROR_REPORTING` and `VALGRIND_ENABLE_ERROR_REPORTING`.
It would drop the same reports, but with them every other error in a
collection: one in the collector itself, a block whose tag was
overwritten, a pointer field the program left undefined in the heap.
`MAKE_MEM_DEFINED` on a copy drops exactly the reports that come from
the stack's own words and nothing else.

### Where

- **Linux and FreeBSD** on x86-64 and arm64 (atla, sadric, alerik,
  rackhir), and i386 where valgrind runs: the client requests are real.
- **OpenBSD and NetBSD**: valgrind does not run there, and valgrind.h
  defines `NVALGRIND` itself, so `RUNNING_ON_VALGRIND` is the constant 0,
  `MarkRangeDefined` is never called, and `DefinedWord` is a plain read.
- **VAX/VMS**: `rtl/vax`'s collector is untouched.

## What it costs

Run natively, `Collect` calls `UnderValgrind` once in the program's life
(a few instructions that change nothing), and each stack scan tests one
`BOOLEAN`. A test per word, in the first prototype, cost GcBench about 3%
more instructions and 8% more cycles; with the test out of the loops,
GcBench (`tools/bench/GcBench.mod`, `-OC`, atla) runs 0.1% more
instructions and its cycles are within noise.

Under valgrind each word of a stack is a call and a client request:
the scan is slower there, and nothing else is.

## Results

Under memcheck with no suppressions (`valgrind --leak-check=full`, atla,
2026-11-18), the old collector and this one:

| Program | old | new |
|---|---|---|
| pogeminilib `TestText`, whole-record copy restored | 700,877 errors | 0 |
| posockets `TestFileServer` | 977 errors, `DrainMarkStack`'s among them | 0 |
| posockets `TestEcho`, `TestForward` | 0 | 0 |
| fixture `llvm-gc-valgrind` | 17 (11 `MarkCandidate`, 6 `DrainMarkStack`) | 0 |

Every test passes its own checks with both. A program that stores a
`malloc`'d word it never wrote in a heap record and branches on it is
still reported with this collector, and valgrind's `--tool=none` runs
everything as before.

The fixture `llvm-gc-valgrind` makes both kinds of report on purpose:
its C part fills a frame with the address of a chain of blocks nothing
else reaches, returns, and calls back into Oberon from a frame of the
same depth whose slots it never writes, and the callback collects. It
expects no errors from memcheck, and where there is no valgrind it skips
that run and writes the line it would.

## After a release

When a released poc has this, the projects can drop their suppressions
for the collector, after a run without them shows none is needed:
`test/poc-gc.supp` in pofltk, pogeminilib, polibfyaml, polibtls,
posockets and pounix, poDB's collector entries in `test/valgrind.supp`,
and posockets' `test/TestFileServer.supp`. pogeminilib can also go back to copying the
record whole in `TestText` and correct its note about padding.

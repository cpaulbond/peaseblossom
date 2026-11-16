# Coroutines under valgrind

posockets found (2026-11-15) that valgrind's memcheck cannot follow a
program's coroutines: its `TestTasks` reached memcheck's limit of
10,000,000 errors. This document is why, found and tried on atla on
2026-11-15 with poc 0.13.0 and valgrind 3.27.1 (Fedora 44, x86-64), what
the fix must settle, and the plan. Its entry in `PLAN.md` is "Ongoing bug
fixing", 21. Only the LLVM back end is concerned: valgrind does not run on
VAX/VMS.

## What happens

A program of two tasks that print and `Tasks.Yield` three times each, and
nothing else, runs correctly, under valgrind too, but memcheck reports 23
errors from 15 contexts: "Conditional jump or move depends on
uninitialised value(s)" at the `ldmxcsr` and `fldcw` of
`Coroutines.-switch`, then "Use of uninitialised value of size 8" in
`Tasks.Block`, `Tasks.Trampoline`, the tasks' `Run`, `Coroutines.Transfer`
and `Coroutines.Free`. It warns "client switching stacks?" twice, at the
switch from `main` to the first task and at the last one back.

| Program | Coroutines | Errors |
|---|---|---|
| two tasks that yield | 2 tasks | 23 from 15 contexts |
| the User's Guide's `Primes 50` (a chain of filter tasks) | 1 per prime found | 26,318 from 100 contexts |
| the User's Guide's `Queens -n 6 4` | 1 | 0 |

## Why

memcheck keeps track of which stack memory is defined from the moves of
the stack pointer. A move down is taken for a push: the memory passed
over becomes undefined. A move up is taken for a pop: the memory left
below becomes inaccessible. A move larger than `--max-stackframe` (2 MB by
default) is the one exception: memcheck takes it for a switch to another
stack, says "client switching stacks?", and marks nothing. A move into a
stack the program has registered with `VALGRIND_STACK_REGISTER` is always
a switch, whatever its size; the main stack is known to valgrind already.

`CoroutinesNewStack` (`rtl/llvm/Coroutines.c`) gets each stack from
`mmap` and does not register it. `mmap` places the stacks next to each
other, below the libraries and far from the main stack: in the
two-task program at `0x4861fb8` and `0x4866fb0`, 20 KiB apart (16 KiB,
`Coroutines`' least, and the guard page), against the main stack's
`0x1ffeffef20`. So:

1. The switch from `main` to a task moves about 128 GB, and is taken for
   the switch it is. These are the two warnings.
2. A switch from one task to another moves about 20 KiB, and is taken for
   a push or a pop. Going down to the other stack makes everything
   between undefined, the other task's saved frame and live stack
   included, so it resumes with undefined registers, and everything it
   computes from them is reported. Going up makes the memory below
   inaccessible, hence posockets' invalid reads.

So it takes two coroutines or more. With one, as in `Queens`, every switch
is between that stack and `main`'s, and is taken for a switch.

## Why `--max-stackframe` cannot help

The limit would have to be less than the distance between two coroutine
stacks, and more than any frame the program makes on one. There is no such
number: at 4000 the two-task program gets 448 errors from 26 contexts,
since now frames on the main stack are taken for switches, and at 100,000
and 4,000,000 it gets the same 23.

## The fix, tried

With one line added to `CoroutinesNewStack`, after it has set `*high`,

```c
(void)VALGRIND_STACK_REGISTER(memory + page, memory + total);
```

and the programs built against that copy of `rtl/llvm` (`poc
-clear-library-path -import-path <copy>`), the two-task program and
`Primes 50` get 0 errors and no warning, and `Queens` still 0. Each
program's output is unchanged.

## `valgrind.h`

The requests are macros, wholly in `valgrind.h`: nothing is linked, and a
program does not need valgrind to build or run.

- **What a request is.** `VALGRIND_DO_CLIENT_REQUEST_EXPR` stores the
  request and its arguments in a small array on the stack, then runs a
  sequence that changes nothing: on x86-64 four `rolq` of `%rdi` adding to
  128 bits and `xchgq %rbx,%rbx`, on i386 the same with `%edi` adding to 64,
  on arm64 its own. Run natively it costs those few instructions, and the
  macro's value is its default, 0. Under valgrind the translator
  recognizes the sequence and passes the request to valgrind's core, which
  keeps the table of stacks, so every tool honors it, not only memcheck.
- **Where.** The header chooses its sequence by system and architecture:
  Linux and FreeBSD on x86, x86-64 and arm64 among them, so atla, sadric,
  alerik and rackhir. On OpenBSD and NetBSD it defines `NVALGRIND` itself,
  and each macro is only its default value: no assembly, and nothing to
  break the build. valgrind does not run there.
- **Its licence.** BSD-style, for this one file, so that programs can
  include it; the rest of valgrind is GPL 3. It is made to stand alone.

`valgrind.h` is in `valgrind-devel` on Fedora (not installed on atla) and
`valgrind` on Debian, where it is installed at all. An `#ifdef` on the
header's being present would make the fix depend on the machine that
built the runtime: the Fedora, Debian and ports packages would have it
only with a build dependency on valgrind's headers. So the header is
copied, whole and unchanged, into `rtl/llvm` beside `Coroutines.c`, which
includes it with quotes, and a later valgrind's copy can replace it. The
packages' copyright records must name it (`packaging/debian/copyright`
and the RPM's `License`).

## Deregistering

`VALGRIND_STACK_REGISTER` returns an id, and `VALGRIND_STACK_DEREGISTER`
takes it. `CoroutinesFreeStack` is given only the stack's bounds, so the id
must be kept. Without deregistering, valgrind keeps an entry for every
freed stack, mostly harmless but wrong: a later mapping at those
addresses would be taken for a stack.

The id goes in `Coroutines`' descriptor, beside the bounds: `NewStack`
returns it through one more `VAR` parameter and `FreeStack` takes it, so
`DescriptorRecord` gains one `SYSTEM.ADDRESS` (`unsigned` in the header;
0 when not under valgrind). Keeping it in the stack's own memory, a word
above the first frame, was considered: it changes nothing in Oberon, but
it takes a word from the stack and makes the first frame's layout, now one
per architecture, carry it.

## Plan

1. **The header.** `rtl/llvm/valgrind.h` from valgrind 3.27.1, unchanged;
   a line in `rtl/llvm/README.md` and in the packages' copyright records.
   Check that a change to it rebuilds `Coroutines.c`'s object
   (`RTL_C_SRCS` in `GNUmakefile` names only `*.c`), and that `make dist`
   carries it.
2. **Register and deregister.** In `CoroutinesNewStack` and
   `CoroutinesFreeStack`, with the id in the descriptor. A comment says
   why: memcheck takes a switch between neighbouring stacks for a push or
   a pop.
3. **A fixture**, `coroutines-valgrind`: the two-task program and `Primes`
   under memcheck (`--error-exitcode`), expecting 0 errors; where valgrind
   is missing it prints the same expected output and says it skipped, so
   it passes on OpenBSD and NetBSD (`testresult.sh`, as every fixture).
   atla, alerik and rackhir run it for real if valgrind is installed
   there.
4. **The documents.** `doc/developer/coroutines.md` and the User's Guide's
   chapter on coroutines: a program using coroutines or tasks can be run
   under memcheck.
5. **posockets** runs its task tests under memcheck again, in place of
   `--tool=none --track-fds=yes`.

# The CPU for 32-bit x86

`PLAN.md`'s open design question "The lowest 32-bit x86 CPU", decided with
the user on 2026-11-18. Since then poc gives clang `-march=i686` for a
32-bit x86 Linux target and leaves every other target at clang's default
CPU (`LLVMTypes.TargetCPUOption`, fixture `llvm-x86-32-cpu`).

## The question

poc must run, and the programs it builds must run, on the user's Pentium
II: an i686 with MMX and without SSE or SSE2. Until this change poc
passed clang no CPU option, so each target got clang's default CPU. The
question, deferred from Phase 11 (2026-09-26) until there were 32-bit x86
test hosts, was whether to fix `-march=i686` for every 32-bit x86 triple.
That would give the same code on all four systems and no SSE2 on Linux,
but it would drop 486 and Pentium machines.

## Each system's default CPU

`clang -### -c` names the CPU it compiles for (`"-target-cpu"`). Checked
2026-11-18 with each system's own clang where there is a 32-bit host, and
with atla's for the rest:

| Target | clang | Default CPU | SSE |
|---|---|---|---|
| `i686-pc-linux-gnu`, `i386-unknown-linux-gnu` | atla, 22.1.8 | pentium4 | SSE2 |
| NetBSD 11.0 i386 (`i386-unknown-netbsdelf11.0`) | yishana, 21.1.8 | i486 | none |
| OpenBSD 7.9 i386 (`i386-unknown-openbsd7.9`) | cymoril, 19.1.7 | i586 | none |
| `i386-unknown-freebsd`, `i686-unknown-freebsd` | atla's and alerik's | i686 | none |

So only Linux's default is above the Pentium II. Each BSD's default is
that system's own floor, the CPU its C library and packages are built
for.

FreeBSD stopped making i386 releases and packages with 15.0 (the
`freebsd-arch` thread "Deprecation of i386 and 32-bit powerpc for 15.0",
June 2025), but kept `lib32`, which runs i386 programs on amd64. So there
will be no 32-bit FreeBSD test host. alerik (FreeBSD 15.1 amd64) runs
poc's i686 programs through `lib32`, as `llvm-i686-runtime` does.

## What the default puts in poc's code

A probe module copied and summed arrays of `LONGREAL` and converted the
sum to `REAL` and to an integer. It was compiled for `i686-pc-linux-gnu`
together with the runtime modules it imports and the runtime's parts in C
(`Platform.c`, `Coroutines.c`, `StopRequests.c`). The number of
instructions on an SSE register (`%xmm`) in the objects:

| CPU | `-O0` (poc's default here) | `-O2` |
|---|---|---|
| default (pentium4) | 274 in the probe; 26-44 in `FormattedOutput`, `FormattedText`, `RealDigits`; 10 in `Platform.c` | 115 in the probe; 64 in `FormattedOutput`; 25 in `Platform.c`; 22 in `StopRequests.c` |
| `-march=i686` | none | none |

The SSE2 comes from real arithmetic, from block copies (an array or
record assignment) and from conversions between integers and reals: for
a CPU with SSE2, LLVM computes `REAL` and `LONGREAL` in its registers
rather than the x87's. So a Linux program poc built for 32-bit x86 would
die with an illegal instruction on a Pentium II, and at `-O0` as much as
at `-O2`.

With `-march=i686` Linux's reals move to the x87, as the BSDs' always
were (`AGENTS.md`, "Overflow, division and reals"). At `-opt 0`, the
default for 32-bit x86, every result is stored and so rounded to its
type, and the suite's 32-bit run (`llvm-i686-runtime`) prints what the
64-bit fixtures expect, as before. At `-opt 1` and up the x87's wider
registers can change a last digit: under `make check-opt2`
`llvm-i686-runtime` printed `9.9999999999999991D+039` for `1.0D40` in
`llvm-out-extra`'s output, which expects `9.9999999999999979D+039`, as
OpenBSD i386 did in Phase 11. `check-opt2` already left that fixture out
on the BSDs and on 32-bit x86 hosts for this reason, and now leaves it
out everywhere.

Between the lower CPUs the only difference in this code is `cmov`, which
the i686 added: at `-O2` there are none for i486 or i586, and 37 for i686.
The Pentium II has `cmov`. Nothing a program can observe depends on
whether a choice is made with a branch or with `cmov`.

## The options

- **A. Leave it.** Linux builds keep needing SSE2. On Fedora, whose i686
  baseline itself includes SSE2, that changes nothing for a Pentium II,
  which cannot run Fedora's libraries anyway. But a Linux whose i386 port
  is plain i686 runs on a Pentium II, and there poc's programs would die.
- **B. `-march=i686` for every 32-bit x86 target.** The same code on all
  four systems. NetBSD and OpenBSD, whose own systems run on 486 and
  Pentium machines, would lose them to gain only `cmov`.
- **C. `-march=i686` only where the default CPU is above i686**, which
  today is Linux alone. This removes the one real break with the Pentium
  II, and each BSD keeps the CPU its own system is built for. Code differs
  among the systems only in `cmov`.

**C was chosen** (the user, 2026-11-18).

## The change

- `LLVMTypes.TargetCPUOption(triple, option)` gives `-march=i686` for a
  32-bit x86 triple (`Is32BitX86`) whose operating system component
  starts with `linux`, and nothing for any other triple.
- `LLVMToolchainDriver.AppendTargetOptions` adds it after the `-O` level.
  Every clang command poc runs goes through that procedure: a module's
  object, a module's part in C or C++, the link, and a library's shared
  object. So `-lto`, whose code is generated at the link, gets the CPU too.
- `make check-opt2` skips `llvm-i686-runtime` on every host, not only
  on the BSDs and 32-bit x86 hosts (above).
- The option is part of the command that an object's reuse stamp hashes,
  so objects compiled for 32-bit x86 Linux before the change are compiled
  again. A library built for that target by an older poc keeps its SSE2
  until it is built again.
- Fixture `llvm-x86-32-cpu`: for two Linux, one each of the BSDs' and one
  x86-64 triple, the CPU option in poc's clang command (`-verbose
  -compile`), and whether the assembly the same command writes (`clang
  -S`) uses an SSE register. The x86-64 line shows that the probe does
  make clang use SSE where the CPU has it. Only clang runs, with no linker
  or C library, so every host checks every triple. With the poc before
  the change both Linux lines say "clang's default CPU, uses SSE".

## Linux systems below the i686

clang's default CPU for 32-bit x86 comes from the triple's operating
system alone (`getX86TargetCPU` in clang's
`lib/Driver/ToolChains/Arch/X86.cpp`): i486 for NetBSD, i586 for OpenBSD,
i686 for FreeBSD, and pentium4 for anything else, every Linux included,
whatever the triple's CPU part says (`i386-`, `i486-` or `i686-`). So
without `-march` a stock clang gives pentium4 even on a Linux built for
the 486.

A distribution can lower that by patching clang or by a configuration
file (`<triple>-clang.cfg`), which clang reads even with `--target=`.
poc's `-march=i686` comes after such a file's options and so overrides
it: on a Linux whose clang is configured for the i486, poc's code would
need an i686. That was accepted (the user, 2026-11-19). The 32-bit x86
Linux systems still made are i686 ones (Void; Debian's i386 packages,
since Debian 13 without an installer or kernel), and Linux 7.1 (2026)
began removing 486 support, leaving the Pentium as its 32-bit floor.
Asking clang for its default CPU (`clang -###`) and capping only one with
SSE2 would honor such a file, at the cost of a clang run per build or a
cached answer; it can be added if such a system turns up.

## If a system's default changes

If a BSD's clang raises its default CPU to one with SSE, or a 32-bit x86
system is added, `TargetCPUOption` should cap it as it caps Linux.
`llvm-x86-32-cpu` fails on such a change, since its BSD lines expect no
SSE. A rise that adds no SSE, to i686 say, passes it and changes nothing
for the Pentium II.

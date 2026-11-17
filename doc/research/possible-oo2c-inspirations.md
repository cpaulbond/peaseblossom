# oo2c: language features, tools and libraries poc might borrow

Written 2026-11-16 at the user's request, as research for later: what
OOC's compiler oo2c (2.1.x, the last upstream line, 2011) offers that
might be useful to Peaseblossom. Nothing here is decided. A candidate
taken up later gets its own survey and the user's decision, as in
Phase 19.

The source read is the user's fork, which builds on current Linux and
the BSDs: `/usr/local/sw/src/tkb/oo2c` (git; `README.md`, `NEWS`,
`AGENTS.md`), installed as oo2c 2.2.2 under
`/usr/local/sw/versions/oo2c/2.2.2`. The language changes from oo2c v1
to v2 are described in `doc/from-v1-to-v2/oo2c-v2.texi` there, which
this note cites as "v2 notes".

oo2c's v2 library is **not** what voc ships: voc's
`src/library/ooc{,2}` carry OOC v1's older, smaller library
(`oocStrings`, `oocTextRider`, `oocLongInts`, ...). So Phase 20, as
written in `PLAN.md`, would not reach the modules in section 2.

## 1. Language and compiler lessons

1. **Pragmas and conditional compilation.** `<* IF HAVE_LIB_WSOCK32
   THEN *> ... <* END *>`, `<* DEFINE DEBUG := FALSE *>`, and per-module
   switches such as `<* Warnings := FALSE *>` (`src/OOC/Scanner/
   Pragma.Mod`, about 750 lines; `src/OOC/Config/StdPragmas.Mod`).
   Predefined variables include `TargetOS`, `TargetInteger` and
   `TargetAddress`, set by configure. poc has none and chooses between
   systems by the import path (`doc/developer/design-decisions.md`,
   near line 436; `doc/reference-guide.md`, near line 1343). With
   LLVM on four Unix-likes and VAX/VMS, this is the design to study if
   choosing by import path becomes painful.

2. **Exceptions** (v2 notes, "Exceptions"): `TRY S CATCH T1(t1): C1
   CATCH T2(t2): C2 END`, the predeclared `RAISE`, and `PROCEDURE P()
   RAISES E` on procedures and procedure types. An exception is a
   record extension caught by type, as in a `WITH`. Exceptions
   extending `Exception.Checked` must be caught or declared, while
   extensions of `Exception.Unchecked` need not be. `ExceptionDesc` is
   not exported, so a program extends one of those two. An exception
   not caught is written to stderr and ends the program.
   - Lowered to `setjmp`. Their own implementation notes warn that its
     cost differs by about ten times between architectures (72 bytes
     on ix86, 768 on PPC), and that `RAISE` saves a backtrace of 20
     frames where glibc has `backtrace()`.
   - poc's rule that a feature costs nothing for programs that do not
     use it would argue for another lowering: VMS condition handling
     (`LIB$SIGNAL` and handlers) on the VAX, and setjmp or LLVM's
     `invoke`/`landingpad` on LLVM. Any design must also say how it
     meets `Coroutines`/`Tasks` (nothing may unwind across a switch),
     finalizers and `StopRequests`.

3. **Parametric types** (v2 notes, "Parametric Types"): `TYPE
   ArrayList*(E: Object.Object) = POINTER TO ArrayListDesc(E)`, used
   as `ArrayList(MyElement)`. A type parameter is bounded by a record
   pointer, and an argument must extend the bound. Type-bound
   procedures name aliases for the parameters in the receiver: `PROCEDURE
   (r: P(T1, T2)) Proc`. A bare `T` means `T(B1, ..., Bn)`. Checking is
   static, with one shared implementation (erasure), so the back ends
   need nothing new. It is the cheapest generics design that fits
   Oberon, and the EBNF is at the end of that section. Polymorphic
   procedures (free type parameters on a procedure) are not supported.

4. **`INIT` and `NEW(T, args)` as a function** (v2 notes,
   "Initialization Functions"). An exported type-bound `INIT` binds to
   the receiver's *static* type, its parameters need not match the
   base type's, and a missing super-call `l.INIT^(...)` draws a
   warning. `v := NEW(T, a1, a2)` allocates and calls `INIT`. `NEW(v)`
   as a statement does not call `INIT`. This overlaps partly with
   poc's record field initializers.

5. **`STRING`** (v2 notes, "Built-in Type STRING"): a predeclared alias
   for `Object.String` (Unicode), with string constants converted to
   it (interned once at module initialization) and `+` for
   concatenation. A cautionary example: `=`/`#` still compare
   identity, and equality is `Equals`.

6. **Doc comments** (v2 notes, "Doc Comments"): `(** ... *)` documents
   the declaration before it, marked up in a Texinfo subset. The
   cross-references `@omodule`, `@oconst`, `@otype`, `@ovar`,
   `@oproc`, `@ofield` and `@oparam` are checked by the compiler. A
   designator prefixed by `*` is not checked. `@precond`/`@postcond`
   blocks. oo2c writes a module's interface and its doc strings as
   HTML (`src/OOC/Doc/`). poc's `tools/rtl-reference` already makes the
   runtime chapter from comments. Checked cross-references and an
   interface-to-HTML output would extend it.

7. **Tools.**
   - `oowhereis` (`src/oowhereis.Mod`) reports where a module is found
     on the search path.
   - `oo2c` can list every use of a declaration (`src/OOC/
     SymbolTable/Uses.Mod`).
   - `ooef` (`src/ooef.Mod`) converts oo2c's error messages into
     other formats.
   - `StupidPP` (`src/OOC/AST/StupidPP.Mod`) is a pretty printer that
     writes the syntax tree back, without comments.
   - H2O (`src/H2O/`) translates C headers to Oberon interface
     modules. It is the Unix counterpart of poc's `tools/sdloberon`
     and might serve for `["C"]` declarations of libc or other
     libraries.

8. **Repositories and packages** (v2 notes, "Programs"): a repository
   is a directory holding `src/`, `sym/`, `obj/` and `pkginfo.xml`.
   `oo2c` builds, installs and uninstalls packages described by
   `pkginfo.xml`, documentation included. poc's libraries and their
   manifests (`src/driver/Libraries.Mod`) already cover most of this.

9. **The optimizer and the backends.** `src/OOC/SSA/` is a GSA/SSA
   optimizer: constant propagation, CSE, PRE, alias analysis, dead
   code elimination, loop rewriting, `Destore`. `src/OOC/X86/` is an
   experimental x86 back end, abandoned. LLVM makes the optimizer moot
   for poc's LLVM back end. If the VAX back end ever wants more than
   straightforward code, `SSA/Allocator.Mod` (a register allocator
   over an interference graph, `IGraph.Mod`) and `Schedule.Mod` are
   examples written in Oberon.

10. **Run-time checks.** The defaults in `StdPragmas.Mod` turn index,
    dereference, `CASE` selector, function-result and type-guard
    checks on, and overflow and range checks off. This is close to
    where poc already landed (`AGENTS.md`, "What traps, and what does
    not").

11. **A fork's lesson.** The fork's v2.2.0 made a nested procedure used
    as a procedure value an error, as the report requires, because the
    generated C would have needed an executable stack (GCC nested
    functions). poc has the same rule.

## 2. Libraries

Paths are under `lib/src/` in the oo2c tree. The licence is the LGPL
unless a module says otherwise. `Codec.Mod` is GPL. Many of these use
oo2c's own extensions: `[OOC_EXTENSIONS]`, `STRING`, parametric types,
`TRY`, hierarchical module names `MODULE A:B`, and `[FOREIGN "C";
LINK FILE "x.c" END]` modules with C parts. Taking one means adopting
some of those extensions or rewriting it in strict Oberon-2. That
choice, parametric types above all, is probably the real decision
before any of these libraries.

| Module(s) | What it is | Fit for poc |
|---|---|---|
| `Object/BigInt.Mod` (about 1000 lines) | Integers of any magnitude, a reformulation of Python's `longobject.c` (no Karatsuba) | Pure Oberon and portable, VAX included |
| `StringSearch/*` | DFA regular expressions (`RegexpDFA`, `RegexpParser`), Boyer-Moore (`SubstringBM`) and brute-force (`SubstringBF`) substring search | Pure Oberon. poc has nothing like it |
| `ADT/*` | `ArrayList`, `Dictionary` (with `AddressKey`, `IntValue`), `LinkedList`, `StringBuffer`, `Comparator`; `Storable` and `Object/Storage` serialize graphs of objects | The collections use parametric types, or would need a non-generic copy |
| `XML/*`, `URI/*` | A callback XML 1.0 parser with namespaces, DTD validation and UTF-8/UTF-16 codecs; URI parsing, hierarchical and opaque | Pure Oberon, large |
| `Codec/*` | UU, yEnc, Twofish, Latin-1, UTF-32, Deflate through zlib | Mostly Oberon. zlib is an outside C library |
| `IO/*`, `IO/Select`, `IO/Socket*`, `Net/HTTP` | Channels over file descriptors, `select`, sockets, a small HTTP client | The sockets are relevant to the "Later" sockets item in the Tasks plan, on POSIX at least |
| `OS/Path`, `OS/ProcessManagement`, `OS/ProcessParameters` | Path names; process creation modelled on Python's `os` | Small. poc's `Directories` covers part |
| `WeakRef.Mod` (75 lines) | Parametric weak references | Would need a hook in `GarbageCollectedHeap`'s collector, beside `RegisterFinalizer` |
| `Logger.Mod`, `Log.Mod` | Logging with separate report and debug logs and pluggable targets | Small, pure |
| `Termination.Mod` | Procedures called at exit, on traps and on termination signals | poc already has finalizers and `StopRequests` |
| `HashCode.Mod` | Hash functions for the basic types | Small; C part |
| `Exception.Mod`, `Object.Mod`, `Object/Boxed.Mod` | The run-time side of exceptions, `STRING` and boxed values | Only with the language features of section 1 |

## 3. Where to look first

If one candidate is taken up, the order of reading in the oo2c tree:

- `doc/from-v1-to-v2/oo2c-v2.texi`: the language extensions, with an
  example module using strings, parametric types, exceptions and
  `INIT` together (appendix "Example Module").
- `doc/language/oberon2.texi`: the language as oo2c accepts it.
- `src/OOC/Scanner/Pragma.Mod` and `src/OOC/Config/StdPragmas.Mod`:
  pragmas.
- `src/OOC/SymbolTable/TypeRules.Mod`: the type rules, parametric types
  included.
- `lib/src/RT0.Mod`, `RT0.c`, `__oo2c.h`: the runtime.

# Sized integers and cardinals: how they convert (reviewed 2026-11-18)

A review of how poc's signed integers (`SHORTINT`, `INTEGER`, `LONGINT`,
`HUGEINT`, `SYSTEM.INT8`..`INT64`, `SYSTEM.ADDRESS`) and unsigned ones
(`SHORTCARD`, `CARDINAL`, `LONGCARD`, `HUGECARD`, `SYSTEM.CARD8`..`CARD64`,
`SYSTEM.CARD`) convert into each other, asked by the user on 2026-11-18:
does `VAL(T, x)` convert between all of them, what happens when a larger
value goes into a smaller type, and should more of them be assignment
compatible? The rules are in `language-extensions.md`, "SYSTEM subset",
"Unsigned integer types" and "Predeclared unsigned types"; what follows
was checked against those sections and by probes compiled with
`build/bin/poc` at `28c93cf` (LLVM backend, `-O2`, x86-64).

## Short answers

- **`VAL` converts between every pair of integer types**, of either
  family, constant or not, with no import. Its bits are `SYSTEM.VAL`'s: `x`
  extended by its own signedness (a CARD zero-extended, a signed value
  sign-extended), then truncated to `T`.
- **A value too large for its target is truncated** to the target's low
  bits, unless `-range-checks` is given, when `VAL` traps (status 14, "VAL
  argument out of range"). A *constant* that does not fit is a
  compile-time error with or without the flag.
- **Assignment never narrows and never crosses the families.** Each family
  is a chain by byte width; an unsigned type is included in `REAL` and
  `LONGREAL`, but in no signed type, and no signed type in it.

## What converts what

| From → to | Assignment | `VAL(T, x)` | `SYSTEM.VAL(T, x)` | `SHORT` / `LONG` |
|---|---|---|---|---|
| Signed narrower → wider (`INT8` → `INTEGER`) | yes | yes | yes | `LONG` |
| Signed wider → narrower | error | truncates; traps under `-range-checks` | truncates, never traps | `SHORT` truncates; traps under `-range-checks` |
| Unsigned narrower → wider | yes | yes | yes | `LONG` (zero-extends) |
| Unsigned wider → narrower | error | as for signed | as for signed | `SHORT`, as for signed |
| Unsigned → signed (any widths) | **error** | yes (zero-extend, truncate) | yes | none |
| Signed → unsigned (any widths) | **error** | yes (sign-extend, truncate) | yes | none |
| Either family → `REAL`/`LONGREAL` | yes | no (integers only) | bit reinterpretation | none |

Two types of one width include each other within a family: `SYSTEM.INT32`
and `LONGINT` under `-O2`, `SYSTEM.CARD16` and `CARDINAL` under `-O2`,
`SYSTEM.ADDRESS` and the integer type of its width, `SYSTEM.CARD` and the
unsigned type of its width.

`VAL` takes integers only: `VAL(REAL, c)` ("VAL's first argument must be an
integer type") and `VAL(CARDINAL, 'A')` ("VAL's second argument must be an
integer") are refused. `ORD` is still the way from a `CHAR`, and
`SYSTEM.VAL` the way to sets and raw bits.

Arithmetic overflow wraps in both families under every flag ("Overflow,
division and reals"; "Unsigned integer types"). Only `VAL`, `SHORT` and
`CHR` under `-range-checks` turn a value that does not fit into a trap.

## Probes

Run, `-O2`:

```
VAL(SYSTEM.CARD8, h)     h = 300 (HUGEINT)        → 44
VAL(SYSTEM.CARD64, li)   li = -1                   → FFFFFFFFFFFFFFFF
VAL(SYSTEM.INT8, hc)     hc = MAX(HUGECARD)        → -1
VAL(SYSTEM.INT8, c8)     c8 = 200                  → -56
VAL(LONGCARD, cw)        cw = VAL(SYSTEM.CARD, a), a = 1234 → 1234
VAL(LONGINT, c)          c = 65535 (CARDINAL)      → 65535
the same program with -range-checks                → "VAL argument out of range", exit 14
```

Compiled, `-O2`, with `i8: SYSTEM.INT8; c8: SYSTEM.CARD8; i: INTEGER;
li: LONGINT; c: CARDINAL; r: REAL`:

| Statement | Result |
|---|---|
| `i := c8` | not type-compatible: `SYSTEM.CARD8` to `INTEGER` |
| `li := c` | not type-compatible: `CARDINAL` to `LONGINT` |
| `c := i8` | not type-compatible: `SYSTEM.INT8` to `CARDINAL` |
| `i8 := li` | not type-compatible: `LONGINT` to `SYSTEM.INT8` |
| `c8 := c` | not type-compatible: `CARDINAL` to `SYSTEM.CARD8` |
| `r := c` | accepted |
| `c8 := VAL(SYSTEM.CARD8, 300)` | VAL's constant does not fit its type |
| `c8 := VAL(SYSTEM.CARD8, -1)` | VAL's constant does not fit its type |
| `IF c8 < i THEN END` | an unsigned and a signed integer cannot be mixed (use VAL) |
| `r := VAL(REAL, c)` | VAL's first argument must be an integer type |
| `c := VAL(CARDINAL, 'A')` | VAL's second argument must be an integer |

## Should more of them be assignment compatible?

**Within each family they already are, as far as is safe.** Inclusion goes
by byte width, and narrowing is an error, as the report has it for the
signed types.

**Across the families, one rule would be safe to add**: an unsigned type
included in every *strictly wider* signed type, so `CARD8` ⊆ `INT16` and
up, `CARD16` ⊆ `INT32` and up, `CARD32` ⊆ `INT64`. Every value converts
exactly. C# has this rule (`uint` → `long` implicitly, `int + uint` a
`long`).

- **For:** it removes the commonest reason for `VAL` noise. `li := c` with
  `c` a `CARDINAL` under `-O2`, or `c < LEN(a)` with `c` narrower than
  `LONGINT`, would compile as written.
- **Against:**
  - The inclusion order stops being one chain per family, and "the
    smallest type including both" sometimes jumps a size: `CARD32 +
    LONGINT` under `-O2` becomes a `HUGEINT` operation, which costs more
    than it looks on the VAX.
  - It goes against the Oakwood Guidelines' recommendation and the user's
    decision of 2026-10-08 (explicit conversion between the families).
  - It does not help the case that hurts most, `SYSTEM.CARD` (C's
    `size_t`) against `LONGINT` or `ADDRESS` on a 64-bit target: they are
    the same width, so `VAL` would still be needed there.

**What should stay an error:** signed into unsigned at any width, and any
mix at one width. Each of those can silently change a value (-1 becomes
`MAX`), which is what the separate family exists to prevent.

**Recommendation:** leave the rules as they are, or add only the
strictly-wider unsigned-to-signed inclusion, for assignment, parameters
and expressions alike. It is a real but modest convenience; adopting it
would mean revisiting `doc/research/unsigned-survey.md` and recording the
decision under "Unsigned integer types", since it changes a choice made
explicitly.

**A smaller gap:** `VAL` refuses a `CHAR`, so `VAL(SYSTEM.CARD8, ch)` must
be written `VAL(SYSTEM.CARD8, ORD(ch))`. Letting `VAL` take a `CHAR`
argument would be a smaller, uncontroversial change if that pattern turns
up in pofltk or the other bindings.

Nothing in poc's rules was changed as a result of this review.

# The bindings' integer types and `SYSTEM.VAL` (surveyed 2026-11-18)

A follow-up asked by the user the same day: how the bindings built with
poc use integers and `SYSTEM.VAL`, whether CARDs, sized integers or
plain `VAL` would serve them better, and whether the unsigned types are
useful for hashing and encryption. Surveyed read-only: pofltk (`devel`
at `9d42382`), poDMSFIELDS, poPOISE-DMS, poDateTime, polibfyaml,
posockets, polibtls, poDB and pounix in `~/Repos/Oberon`, and poc's own
`rtl/llvm` and `rtl/vax`. The findings below were spot-checked against
the sources; the projects themselves were not changed.

## Summary

The bindings are sound. Every C binding passes values through its own
C or C++ shim, which normalizes C's types to `int32_t`, `int64_t`,
`intptr_t` or `uintptr_t`, and the Oberon side declares them
`SYSTEM.INT32`, `INT64` or `ADDRESS`, so byte order, ports, `size_t`,
`off_t` and C's unsigned types stay in C. No `["C"]` signature uses a
plain `INTEGER` or `LONGINT` except the one listed under pofltk below.
**Most `SYSTEM.VAL`s are not integer conversions at all** but
pointer, procedure, address, `SET` or real-bit reinterpretation, which no
integer type replaces. Of the integer conversions, most predate the
predeclared `VAL` (0.11.0) and would read better as `VAL`, which also
traps under `-range-checks` where `SYSTEM.VAL` truncates silently. No
project uses `SHORTCARD`, `CARDINAL`, `LONGCARD`, `HUGECARD` or plain
`VAL` yet.

## Latent bugs found

In poc's runtime (recorded in `PLAN.md`, "Ongoing bug fixing", 25 and
26):

- **`In.Int`, `In.LongInt`, `InStr.Int` and `InStr.LongInt`** read a
  `HUGEINT` and store it with `SYSTEM.VAL`, so a number too large for
  the variable is truncated with `Done` still TRUE: under `-O2`, reading
  `70000` into an `INTEGER` gives 4464 (reproduced). Both back ends.
- **`Files.PositionStream`** (`rtl/llvm/Files.Mod:262`) passes
  `SYSTEM.VAL(SYSTEM.ADDRESS, position)` to `fseek`; on i386 under `-OC`
  a position of 2^32 + k seeks to k. From the code, not reproduced.
- Behaving as voc's do, so not recorded as bugs: under `-O2`,
  `Platform.SetIdentity` (`Platform.Mod:449-451`) truncates 64-bit
  device and inode numbers to a 32-bit `LONGINT`, so `Platform.Same`
  could take two files for one, and `Size` wraps past 2 GiB.

In the VMS applications:

- **`SYSTEM.VAL(SYSTEM.CARD16, SHORT(n))`** for a descriptor length
  (`poPOISE-DMS/src/Fio.Mod:220`, `Utl.Mod:539`, `Utl.Mod:2022`;
  `poDMSFIELDS/src/Lines.Mod:78`). `SHORT` gives a *signed* 16-bit value
  under both size models, so a valid length of 32768 to 65535 traps
  under `-range-checks`, and a length above 65535 wraps silently
  (`Fio.Bytes` clamps to `LEN(data)`, not to 65535). Fix: clamp to
  65535 and use `VAL(SYSTEM.CARD16, n)`.
- **`FldMsg.Exit`** (`poDMSFIELDS/src/FldMsg.Mod:136`) adds
  `STS$M_INHIB_MSG` (`10000000H`) to the status instead of setting it;
  a status that already has the bit gets bit 29 instead. Fix: a set
  union. `Utl.Mod:1425` has the pattern on a value it builds itself.

In pofltk:

- **`examples/Contrast.Mod:307`** uses `IF textcolor >= 0` as "a colour
  was given"; an RGB colour with red >= 128 is a negative `INTEGER` and
  would be skipped. No current caller passes one.
- **`src/FlBrowsers.Mod:179`** declares `ofl_browser_column_widths`'s
  `const int32_t*` as `ARRAY OF INTEGER`, the right width only under
  `-OC` (pofltk builds only under `-OC`). The only model-dependent C
  declaration found in any binding.

## Per project

**pofltk** (412 modules; 1405 `["C"]` declarations using `SYSTEM.INT32`,
`ADDRESS`, `LONGREAL`, `ARRAY OF CHAR` and procedure types; no CARD and
no other sized type). C++ does every unsigned cast (`static_cast<Fl_Color>`),
and the public API holds colours, fonts and box types in `INTEGER` and
flags in `SET`. Unsigned C values crossing as `INT32` (`uint32_t` GL
names, the EPS background, an `unsigned char` widened) pass the same
bits. 121 `SYSTEM.VAL`s:

| Class | Count | Better as |
|---|---|---|
| `ADDRESS`/`PTR` to a typed pointer (callbacks, finalizers) | 52 | stays |
| Pointer or procedure to `ADDRESS` | 21 | stays |
| `ADDRESS` to a procedure type | 6 | stays |
| Integer to `SET` (flags) | 31 | stays |
| `SET` to integer | 4 | `ORD(s)` (poc 0.4.1 on) |
| `LONGREAL` to `HUGEINT` bits (sign of -0) | 5 | stays |
| Narrowing integer (`Fl.RGB`, `Fl.Mod:1640`) | 1 | `VAL(INTEGER, ..)` |

Signed colours make several places do unsigned arithmetic by hand,
correctly: `Terminal.Mod:118-121` adds 2^32 to print one in hexadecimal,
`Terminal.Mod:595-606` folds a parsed value back to signed,
`GlPuzzle.Mod:520-522` takes the unsigned GL depths `MOD 100000000H`,
and `Contrast.Mod:166` and `TestCairo.Mod:170-172` take channels by
floored `DIV`/`MOD`. A colour type of `SYSTEM.CARD32` (`CARDINAL` under
`-OC`, the only model pofltk builds under) with
`Out.CardHex` would remove each of them and the `Contrast` sentinel, at
the cost of a public API change and a `VAL` wherever user code mixes a
colour with an `INTEGER`. pofltk's AGENTS.md declined CARD colours for
poc 0.6.0, mainly because every colour computation would need
`SYSTEM.VAL`; the predeclared `VAL` weakens that reason. Declaring the
unsigned C returns (`CSelectValue`, `CLoadName`, `CPushName`, the EPS
background) `SYSTEM.CARD32` would document them with no change to the
ABI.

**poDMSFIELDS and poPOISE-DMS** (273 `SYSTEM.VAL`s, 54 + 219). Statuses
and most values are `SYSTEM.INT32`, bitmasks `SET`; SMG identifiers and
three hand-written array descriptors already use `CARD32`, `CARD16` and
`CARD8`.

| Class | Count | Better as |
|---|---|---|
| Address of an external procedure (141 of them `LIB$SIG_TO_RET`) | 151 | one variable or helper per module; no type helps |
| `SET` to and from `INT32` | 26 | stays |
| `ADR` to `INT32`/`CARD32` (argument lists, `FAB$L_FNA`) | 19 | `ARRAY OF SYSTEM.ADDRESS`; address fields typed `ADDRESS` |
| `CARD16` length widened to signed | ~24 | `VAL(SYSTEM.INT32, d.length)` |
| Signed narrowed to `INT32` (`LEN`, `-OC` `LONGINT`) | ~26 | `VAL` |
| Signed to CARD (lengths, `SYS$EXIT`'s code) | 10 | `VAL` (see the `SHORT` bug above) |

Correct as written: condition-value tests (`ODD`, compares with `SS$_`
constants; bits 29-31 are zero, so a status is never negative) and
bit-field extraction from a signed `INT32` by floored `DIV`/`MOD`.

**The generated STARLET modules** (`tools/sdloberon`) already declare
whatever SDL marks unsigned as `SYSTEM.CARD8` to `CARD64` (1527
`CARD32`, 398 `CARD16`, 341 `CARD8`, 51 `CARD64`), item codes `INT16`
(chain codes are -1) and quadword times `HUGEINT` (delta times are
negative). Condition-value results are `INT32` by design, but four
`COND_VALUE` parameters came out `CARD32` (`STARLET.Mod:1592`,
`SYS$EXIT`'s `CODE`; `:1769`; `:2168`; `SMG_ROUTINES.Mod:602`), and
`STR_ROUTINES.Mod:60` has a `cond_value` result typed `INT16`: worth
making consistent in sdloberon, which would remove the
`SYSTEM.VAL(SYSTEM.CARD32, status)`s in `FldMsg`, `MsgCli` and
`Conditions`. Address-like longwords such as `FAB$L_FNA` are `CARD32`;
typing a short list of them `SYSTEM.ADDRESS` would remove most of the
`ADR` conversions.

**rtl/vax** (about 108): CARD to signed (`DateTimes.Mod:105, 117`,
`Conditions.Mod:144`, `LogicalNames.Mod:99, 102`, `CommandLanguage.Mod:113,
178`, `Symbols.Mod:29, 32`, `TaskInput.Mod:154-155`, `Modules.Mod:241-242`)
and signed to CARD (`SortMerge.Mod:63-67`, `LogicalNames.Mod:50, 55`,
`Conditions.Mod:142`, `VmsArguments.Mod:111, 138`) are `VAL`'s work;
`LogicalNames.Mod:51, 84, 88, 92` wrap small constants in
`SYSTEM.VAL(SYSTEM.INT16, ..)` that plain assignment takes. The
reinterpretations in `In`, `InStr`, `Out`, `Err`, `OutStr`,
`DecimalStrings`, `Texts`, `Reals`, `Math`, `MathL`,
`GarbageCollectedHeap` and `Files` stay.

**The small C bindings.** Each has its own shim; none has a signedness
bug.

- **poDateTime**: 10 C declarations, no `SYSTEM.VAL`. Builds under both
  models.
- **polibfyaml** (`-OC` only): `size_t` as `ADDRESS`; emitter flags,
  which need 32 bits, in `INTEGER` (`Fyaml.Mod:140`), right only under
  `-OC`. 17 `SYSTEM.VAL`: 13 `LONGINT` to `ADDRESS` (a narrowing on
  i386; `VAL`), 2 `ADDRESS` to `LONGINT` (plain assignment under `-OC`),
  2 object casts.
- **posockets** (`-OC` only): `htons` is in C. 11 `SYSTEM.VAL`, all
  identities under `-OC` (`INT64` or `HUGEINT` to `LONGINT`): plain
  assignment.
- **polibtls** (`-OC` only): `uint32_t protocols` as `INT32`, passed
  through. 10 `SYSTEM.VAL`: 3 object casts, 5 identities, 2 descriptor
  narrowings to `INT32` (`Tls.Mod:373, 398`; `VAL`).
- **poDB** (both models): the only CARD use in the C bindings,
  `PQftype`'s Oid as `SYSTEM.CARD32` (`DbPostgres.Mod:141, 735`),
  correct. One `SYSTEM.VAL`. The helpers `ToInteger` and `ToInt32`
  (`DbSqlite.Mod:111-127`, `DbPostgres.Mod:181-197`, 12 calls) and
  `wide := bytes; length := SHORT(wide)` (`DbPostgres.Mod:788`) exist
  only to narrow independently of the size model: `VAL` replaces them.
- **pounix** (`-OC` only): 8 `SYSTEM.VAL`, 6 identities and 2 narrowings
  to `INT32`.

**rtl/llvm** (about 150): `Platform` narrows file handles and
`HUGEINT`/`INT64` values (`VAL`); `Files` converts positions and lengths
between `LONGINT` and `ADDRESS` (see bug 26); `Console`,
`FormattedOutput` and `Modules` convert `LONGINT` lengths to `ADDRESS`;
`TaskWaiting` narrows a timeout `Tasks` has already clamped. The
collector builds unsigned address order by hand, adding `orderBias` =
`MIN(SYSTEM.ADDRESS)` (`GarbageCollectedHeap.Mod:156, 290, 376-380,
986-989`) and writing `end - block > 0` (`927`): correct, and needed on
i386 for a heap above 2^31; `SYSTEM.CARD` keys would make it direct (a
clarity gain only). The `CARD64`/`HUGEINT` bridges in `Out`, `Err`,
`OutStr`, `In` and `InStr`, and `FormattedText.Card`'s hand-made
unsigned digits, are there because voc compiles `Err` (with
`CardinalTypes`) for Stage 0.

## By class, all projects

| Class | Roughly | Better as |
|---|---|---|
| Pointer, procedure, address, object casts | 270 | stays `SYSTEM.VAL` (or, for the VMS external addresses, a helper) |
| `SET` to and from an integer | 65 | stays, except `SET` to integer, which is `ORD` |
| Real or `CHAR` bit reinterpretation | 30 | stays |
| Narrowing integer conversion | 120 | `VAL` |
| Widening, or the identity under the model the code is built with | 75 | plain assignment, or `VAL` |
| Crossing signed and unsigned | 40 | `VAL` |

## Recommendations, most valuable first

1. Fix the latent bugs above: poc's 25 and 26, the four
   `SYSTEM.VAL(SYSTEM.CARD16, SHORT(n))`s, `FldMsg.Exit`'s addition,
   `Contrast`'s sentinel and `FlBrowsers.Mod:179`.
2. Make sdloberon's `COND_VALUE` parameters `INT32` like its results.
3. Replace the integer narrowings, widenings and family crossings done
   with `SYSTEM.VAL` (about 200 across the projects and the runtime) with
   `VAL` or plain assignment, starting with poDB's helpers and rtl/vax,
   both written before `VAL` existed. Projects that do so need poc
   0.11.0 or later (pofltk's makefile asks only for 0.4.1).
4. Consider `SYSTEM.CARD32` colours in pofltk, a public API change.
5. Optional documentation: `SYSTEM.CARD32` for unsigned C values that
   only pass through (libtls `protocols`, pofltk's GL names);
   `SYSTEM.ADDRESS` for the VMS argument lists and address fields.
6. Leave the reinterpreting `SYSTEM.VAL`s alone.

## Hashing and encryption

The unsigned types suit them. Written in poc with `SYSTEM.CARD32` and
`CARD64` as probes (2026-11-18, not kept), SHA-256 (FIPS 180-4) matched
`sha256sum` on the three standard test messages, FNV-1a-64 matched a
Python reference, and CRC-32 gave the standard check value `CBF43926`,
each under both `-O2` and `-OC`. At `-opt 2` the bit helpers inline to
`xor` and `rol` in SHA-256's round function. What makes it work:
arithmetic wraps by promise; `SYSTEM.LSH` of a CARD fills with zeros and
`SYSTEM.ROT` rotates within its width; comparison is unsigned; a
hexadecimal constant such as `0CBF29CE484222325H` is taken by a `CARD64`
as its 64-bit value; `Out.CardHex` prints the result.

The rough edges:

1. **No bitwise XOR, AND, OR or NOT on integers.** They go through sets,
   `SYSTEM.VAL(SYSTEM.CARD32, SYSTEM.VAL(SET, a) / SYSTEM.VAL(SET, b))`
   (`SYSTEM.SET64` for `CARD64`), which costs nothing at run time but is
   verbose; there is no 8- or 16-bit set, so a `CARD8` or `CARD16` must be
   widened first, and helper procedures in another module are inlined only
   with `-lto`. `SYSTEM.XOR`, `AND`, `OR` and `NOT` on integers would be the
   language-level answer, if wanted.
2. **`ORD` is signed,** so each input byte needs `VAL(SYSTEM.CARD32,
   ORD(ch))`; the CRC probe failed to compile without it. This adds to
   the case, above, for letting `VAL` take a `CHAR`.
3. **Cryptography proper**, as against checksums and hash-table hashes,
   should still go through libtls or libcrypto (polibtls): poc promises
   nothing about constant time, and it emits index checks and branches.

None of this was tried on the VAX, where `CARD64` multiplication goes
through runtime routines, so a 64-bit hash such as FNV-1a-64 would be
slow there.

poc's own hashes cannot use the CARD types, since poc's source must stay
strict Oberon-2 that voc compiles: the module keys' FNV-1a-64
(`ModuleInterface.HashChar`, and again in `VaxTypes.AppendHash`) is done
a byte at a time in `INTEGER`s, and `Names.HashOf` is a small
polynomial hash. Ropes' `Hash` (sdbm, as GNAT's `Ada.Strings.Hash`)
computes in `HUGEINT` `MOD 100000000H` because voc builds it too. All are
correct as they are.

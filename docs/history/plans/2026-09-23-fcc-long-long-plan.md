# fcc: `long long` (increment 1 of apple/fgx#447)

2026-09-23. The maintainer decided on 2026-09-23 that fcc gains `long long` before the
64-bit double, so that the llvm-mos soft-double (C over `unsigned long long`)
compiles as-is. Kerberos also needs it (decision 2, 2026-09-19).

## The standard, and what is not verified

`long long` is **not in K&R 2nd ed**. It is a C99 type that fcc adopts as an
extension. No C99 text is indexed in this project (gs-mcp's `kr_c` is K&R
only), so the rules below are the ones K&R already states for `long`, extended
by one rank. **None of it is verified against C99's text**, and every commit
says so rather than citing a clause:

- **Rank.** long long is above long. The unsigned variant keeps the modulo-2^64
  arithmetic A.4.2 gives every unsigned type.
- **Usual arithmetic conversions.** A.6.5's ladder gains a rung above long:
  either operand long long -> both long long, with the same unsigned rule A.6.5
  gives long against unsigned int. A 64-bit long long holds every value of an
  unsigned long, so unsigned long meeting long long converts to long long.
- **Conversions.** A.6.2's integral rules apply unchanged: widening
  sign-extends a signed value and zero-fills an unsigned one, and narrowing
  truncates.
- **Constants.** An `ll`/`LL` suffix, optionally with `u`/`U`, makes a long
  long constant.
  - K&R A.2.5.1 (p.155), read: "If it is unsuffixed and decimal, it has the
    first of these types in which its value can be represented: int, long
    int, unsigned long int. If it is unsuffixed, octal or hexadecimal, it has
    the first possible of these types: int, unsigned int, long int, unsigned
    long int."
  - The extension appends long long and then unsigned long long to both
    lists. K&R's own order, including its `unsigned long int` for a decimal,
    is kept as written.
  - Whether fcc honours K&R's lists today, for example that decimal
    3000000000 is unsigned long, is to be checked in 1e before anything is
    appended.
- **printf/scanf.** The `ll` length modifier.

## Shape: a long with two more words

A long is carried as w0 in A and w1 in `_fcc_long_hi` (DP $EC). The second
operand is in `_fcc_long_b_lo/hi`. Direct page is full, every byte from $98 to
$FF is assigned, so a long long extends the same carrier into the data bank,
beside the float runtime's `_fcc_f_*` cells:

- **Accumulator.** w0 = A, w1 = `_fcc_long_hi`, w2 = `_fcc_q2`,
  w3 = `_fcc_q3`.
- **Second operand.** `_fcc_long_b_lo/hi` plus `_fcc_qb2/qb3`.
- **Consequences.**
  - Narrowing to long costs nothing: w0/w1 are already a long.
  - Widening from long is two stores, a sign or zero fill.
  - Every long path stays byte-identical.
  - Double (increment 2) shares the same four words, because its runtime
    works on the u64 bit pattern.
- **Signals.** Handlers run only at a syscall exit, which is reached from a
  call or a loop back-edge safepoint. At those points no expression temporary
  is live in the accumulator; a value that spans a call is spilled first, as
  longs are today. So `_sig_tramp` needs no new saves. This is an argument, to
  be proved by a fixture that takes a signal inside a long long loop.
- **Storage.** 8 bytes, align 2: four slots in a frame and four words in data.
- **Push, pop and return.** Four words each way. The return value comes back
  in the accumulator.

## Sites

The float inventory in the #447 plan already lists every `LT_LONG` path,
because float rode the long carrier. A long long arm goes beside each
`LT_LONG` arm:

- sizes;
- load and store for locals, globals, deref, arrays and members;
- about 30 statement-level store and compound-assign arms;
- push, pop and return;
- calls and parameters, including K&R;
- casts;
- the usual-conversion helpers `arith_unsigned` and `ast_type_scalar_binop`;
- `!`, `&&`, `||` and conditions;
- `?:`, through the common-type rule just landed;
- `switch`, where the controlling expression may be long long;
- static initializers and constant folding;
- the IR's barrier set, and the DP-IMG promotion exclusion.

## Runtime placement -- DECIDED (the maintainer, 2026-09-23): an optional archive

The routines began in toolchain/lib/fcc_runtime.s.  They cannot stay there.
Every multi-bank binary PUTs that file into EVERY code bank (gen.py and the
tcsh, sh and elvis link generators), so it costs once per bank:

- 1b's routines, about 450 B, left tcsh 91 B short of its 7-bank cap: code
  423,757 B against 423,848 B usable.
- 1c's multiply, divide and remainder made "tcsh does not fit in 7 code
  banks".
- The kernel copy (fcc_rt.s) hit the vfs module's 64 KB object limit, which
  the USER ONLY markers answered.

Decided: the long long routines become a per-tool OPTIONAL ARCHIVE in the
fgx_ar tier, like curses and termcap.  It is dead-stripped per member, so only
a tool that uses long long carries them, once.  The calls are far (JSL/RTL).
1b's routines move out of fcc_runtime.s with them.

## Runtime (65816 assembly)

These run on the accumulator and the second operand, like the `_fcc_long_*`
family, and are written in the main agent:

- `+ - & | ^` and unary `- ~`. Short enough to inline as four-word
  sequences; runtime calls if code size says otherwise.
- `<< >>`: arithmetic and logical right shifts, with the count in A.
- `==` through `>=`, signed and unsigned.
- `*`, and `/ %`, signed and unsigned. Shift-subtract division, 64 by 64.
- Conversions to and from int, unsigned, long and unsigned long. To and from
  float when double lands in increment 2.

## libc

- printf `%lld/%llu/%llx/%llo`.
- `atoll`/`strtoll`/`strtoull` when a port needs them. krb5 1.3.6 is the
  first consumer; to be checked against what its sources call.
- `<limits.h>`: `LLONG_MAX`, `LLONG_MIN`, `ULLONG_MAX`.

## Sub-increments, each gated

- **1a.** Type, lexing (`long long`, `unsigned long long`, the LL/ULL
  suffixes), sizeof, and storage: load, store, push, pop, return and
  parameters for locals and globals. Copying a value is correct with no
  arithmetic. Fixture: round-trip patterns whose four words all differ.
- **1b.** `+ - & | ^ ~`, unary minus, shifts, compares, `!`, conditions,
  switch.
- **1c.** `* / %`, signed and unsigned.
- **1d.** Conversions and the usual arithmetic conversions, mixed with every
  narrower integer type in both orders.
- **1e.** Constants beyond 32 bits, static initializers, arrays, struct
  members, deref, compound assignment, `++`/`--`.
- **1f.** printf `%ll*`, `<limits.h>`.
- **1g.** The llvm-mos `softDouble.c` compiles with fcc. It is the acceptance
  test that increment 3 builds on: nothing ships from it yet, it must only
  compile, and its routines are checked on FGX against the host results from
  the 2026-09-23 harness.

## Status

1a-1g are done on feat/447-long-long.  1g's finding: fcc compiles the
llvm-mos soft double faithfully, and it matches the host on every
arithmetic, compare and conversion vector.  The one exception was
`__floatsidf(INT32_MIN)`, where the source negates an `s32` and overflows
(apple/fgx#493); the derived copy, `toolchain/lib/libdouble/softdouble.c`,
widens before negating.

Every sub-increment gets fixtures whose values are computed on the host, the
tree-impact replay (all 264 fcc commands, old versus new compiler; long paths
must stay byte-identical), goldens, the full runtime oracle, and the gate.

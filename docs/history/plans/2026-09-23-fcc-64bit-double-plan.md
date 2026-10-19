# fcc: a real 64-bit `double` (apple/fgx#447)

2026-09-23. Plan only: nothing is built yet.

**DECIDED (the maintainer, 2026-09-23): option C, by the `long long` route.** fcc gets
`long long` first. Kerberos needs it anyway (decision 2, 2026-09-19). Then the
llvm-mos `softDouble.c` is vendored and compiled as-is as the `_fcc_d*`
runtime. Hot routines may later be hand-translated to 65816 assembly with that
file as provenance, once a measurement asks for it. SANE was the first
recommendation and is not taken; its decimal scanner and formatter remain an
option for printf and atof (increment 6).

`long long` is not in K&R 2nd ed. It is a C99 extension fcc adopts, so its
semantics come from C99 6.2.5/6.3.1.8, and every commit says it is an
extension rather than citing K&R.

## 1. What K&R requires, read from the text

K&R 2nd ed, indexed as `kr_c`.

- **A.4.2 (p.158).** "Any of single precision floating point (float), double
  precision floating point (double), and extra precision floating point (long
  double) may be synonymous, but the ones later in the list are at least as
  precise as those before."
  - So `float == double` is permitted **by this clause**.
- **B.11 (p.213).** "When a value is given, it represents the minimum
  magnitude for the corresponding quantity."
  - `FLT_DIG 6`, `FLT_EPSILON 1E-5`.
  - `DBL_DIG 10`, `DBL_EPSILON 1E-9`.
  - An IEEE single gives about 7 digits and an epsilon near 1.2e-7. It meets
    the FLT rows and fails the DBL rows. **B.11, not A.4.2, is what fcc
    breaks.**
- **A.6.4 (p.159).** "When a less precise floating value is converted to an
  equally or more precise floating type, the value is unchanged."
  - float -> double is exact. double -> float "may be either the next higher
    or the next lower representable value."
- **A.6.5 (p.159-160).** The usual conversions: "if either operand is double,
  the other is converted to double. Otherwise, if either operand is float, the
  other is converted to float."
  - Also: "arithmetic on float operands may be done in single precision,
    rather than double."
  - **So float op float may stay on today's single-precision runtime.** Only
    an expression that involves a double pays for double.
- **A.7.3.2 (p.163).** "If the function declaration in scope for a call is
  old-style, then default argument promotion is applied to each argument ...
  each float argument is converted to double."
  - Arguments past a prototype's `, ...` get the same promotion.
  - For an old-style definition, the comparison is "between the promoted type
    of the arguments of the call, and the promoted type of the parameter". A
    K&R `f(x) float x;` therefore receives a double.
  - This is the widest-reaching consequence. Every float passed to printf or
    to an unprototyped function becomes 8 bytes.

- **A.2.5.3 (p.156).** "The type is determined by the suffix; F or f makes it
  float, L or l makes it long double, otherwise it is double."
  - With A.6.5, `f * 2.0` for a `float f` is **double** arithmetic.
  - So existing float code with unsuffixed literals moves onto the double path
    when this lands. That is the cost that decides section 4.
  - FGX's float users are light: df, ensoniqplay, frotz, trunctree and od.
    fractal is fixed-point. None has an obvious hot numeric loop, but that is
    unmeasured.

`long double` may stay synonymous with `double` (A.4.2), and it has to parse,
which it does not today.

## 2. What fcc does today (inventory, 2026-09-23)

- **It is one type.** `float` and `double` lex to the same token
  (lex_pp.c:1427). Both become `BT_FLOAT` (tword.h:28). The 4-bit base field
  has room for a `BT_DOUBLE`.
- **A float is carried as a long.** The value lives in A:`_fcc_long_hi` and
  the second operand in `_fcc_long_b_lo/hi`. About 311 references in the
  compiler are mostly `LT_LONG || LT_FLOAT` pairs, with 4 bytes hard-coded:
  - sizes at main.c:146/188/195, parse_expr.c:8713, symtab.c and struct
    layout at parse_stmt.c:218;
  - loads and stores for locals, globals, deref, arrays and members;
  - about 30 statement-level store and compound-assign arms in parse_stmt.c;
  - push and pop through `emit_push_long`;
  - return in A plus `_fcc_long_hi`.
- **No promotion.** A varargs or unprototyped float is pushed as 4 bytes
  (parse_expr.c:3170). K&R float parameters are read as 4 bytes.
- **Constants** are converted on the host with `strtof` (lex_pp.c:221). The
  f/F/l/L suffix is discarded, so `1.0f` and `1.0` cannot be told apart.
  Static initializers are converted on the host into 32 bits
  (parse_stmt.c:9094, 3582).
- **Found defects that ride along.** Each is a K&R conformance gap, each gets
  its own commit and fixture, and none needs a double to show:
  - `long double` does not parse (parse_stmt.c:438).
  - `?:` does not balance arithmetic types; it takes the else arm's type
    (parse_expr.c:5472). K&R A.7.16 is to be read before fixing it.
  - A global float array cannot be brace-initialised (parse_stmt.c:8763).
  - A float `switch` is not diagnosed (parse_stmt.c:2222).
- **Outside the compiler.**
  - printf reads `va_arg(ap, float)` (libc_c/printf.c:293) and formats in
    single precision.
  - `atof` computes in single precision (atof.c).
  - od prints `-e/-F` from a 4-byte double (od.c:195).
  - df passes `(double)x/1024.0` to printf.
  - 46 fixtures exercise float. f_decl asserts `sizeof(double)`, f_knr uses a
    `double` K&R parameter, and libcadds says "double IS fcc's 4-byte float".

## 3. The shape

1. **Type.** Add `BT_DOUBLE` (and `LT_DOUBLE*`); sizeof 8, align 2.
   - `float` keeps `BT_FLOAT`.
   - `long double` parses to `BT_DOUBLE`.
   - The lexer keeps the suffix: an unsuffixed literal is double, as in K&R
     A.2.5.3; `f` gives float, and `l` gives long double, which is double.
2. **Transport.** A double does not fit in A plus one DP word.
   - It lives in an 8-byte accumulator, `_fcc_dacc`, and a second operand,
     `_fcc_dacc_b`, both absolute cells in the data bank beside `_fcc_f_*`.
     That keeps within ir.c's "helpers touch only DP $E8 and up" invariant.
   - Loads, stores, pushes and pops move four words.
   - A double return comes back in `_fcc_dacc`.
   - Every `LT_LONG || LT_FLOAT` pair gets a third arm, not a rewrite. Long
     and float paths stay byte-identical, which is what the goldens check.
3. **Conversions and promotion.**
   - Usual conversions per A.6.5.
   - int/long/unsigned <-> double, and float <-> double (A.6.4).
   - Default argument promotion per A.7.3.2: an old-style or `...` float is
     pushed as a double.
   - A K&R `float` parameter receives 8 bytes and is narrowed on entry.
4. **Constants.** Host-side conversion with `strtod` into 64 bits. Double
   static initializers emit four DA words.
5. **libc.**
   - printf's `%e/%f/%g` read `va_arg(ap, double)` and format at double
     precision.
   - `atof` (and `strtod`, which 2.11BSD libc has) return real doubles.
   - `<float.h>` states the true DBL_* values, and the FLT_* ones for single.
6. **Users.** Audit od, df, frotz and fractal for anything hard-coding 4. The
   od `-e/-F` width becomes the real sizeof.

## 4. The decision: where double arithmetic comes from

| | A. SANE, in ROM | B. Hand-written 65816 runtime |
|---|---|---|
| What | Toolbox tool set $0A: `SANEFP816` for arithmetic, compares and conversions; `SANEDecStr816` for decimal scan and format | `_fcc_d*` routines beside today's `_fcc_f*`, in fcc_runtime.s |
| Correctness | "scrupulously conforms to the IEEE standard 754" (Toolbox Ref vol 2 p.317); correctly rounded, including decimal conversion | Ours to prove. Today's single runtime took several increments to get rounding right. |
| Code | Small: one thin shim per operation. printf/atof decimal conversion is done by SANE. | Large: add, sub, mul, div, cmp and six conversions at double width (roughly 1,500+ lines by analogy with the single runtime), plus binary<->decimal conversion written in C |
| Speed | Slow. Vol 2 p.322: add/sub 0.5-1.2 ms, mul 1.0-5.0 ms, div 1.9-5.2 ms, and a double op is about 3 calls through extended | Faster, by an unmeasured factor |
| Availability | "Tools 1 through 13 are ROM-based" (Machine Language for Beginners p.326), so SANE is in every IIgs ROM. FGX already runs the Tool Locator and Memory Manager (stage2; toolbox.s `_GetNewID`). Needs `SANEStartUp` with one 256-byte direct page. | Nothing external |
| Constraints | "SANE is not reentrant" (p.326). Safe here because FGX switches tasks only at a syscall or a safepoint, and no interrupt handler would call SANE. The FP environment (DP bytes 24-29) is one per machine, not per process; that is a stated divergence. | None new |
| libm | `SANEElems816` gives exp, log, sin and the rest | Would need its own port |

**C. The llvm-mos soft-double** (`examples/65816-llvm-mos/runtime/src/softDouble.c`,
397 lines of C over `unsigned long long`). Checked 2026-09-23:

- **Accuracy.** Compiled on the host with the 65816 type widths it assumes,
  and compared bit for bit with the host's IEEE double: **0 mismatches in 3.6
  million add/sub/mul/div operations** whenever inputs and results are normal.
  - It rounds to nearest-even with guard and sticky bits, and it classifies
    NaN and Inf.
  - Every mismatch involves a denormal or NaN input or result: it flushes
    denormals to zero, which K&R does not require.
  - A first host build that left its `u32 = unsigned long` at 64 bits broke
    multiply entirely. That was the build, not the source.
- **Speed**, from the project's own benches with clang -O2
  (STATUS.md:702, SESSION_RECOVERY.md:414): `dmul` about 1,033 cycles and
  `ddiv` about 1,261 cycles, roughly 0.4-0.5 ms at 2.8 MHz. SANE is documented
  at 1.0-5.0 ms for multiply and 1.9-5.2 ms for divide.
  - fcc's code will be slower than clang -O2. How much slower is unmeasured.
- **Route.** Either fcc gets `long long` first, which Kerberos needs anyway
  (decision 2, 2026-09-19), and the C compiles as-is; or the routines are
  translated to 65816 assembly with this file as provenance.
- **Not covered:** decimal conversion. printf and atof need their own, or
  SANE's.

**Original recommendation, before C was measured: A.** It is the native-platform rung. #447 exists because
of precision, and SANE is correct by construction, including the decimal
conversions that are the hardest part to get right by hand. The first
consumer is NTP, which does a few dozen double operations per exchange, so
milliseconds per operation do not matter. Float code keeps today's fast
single-precision path (A.6.5), but only where its constants carry an `f`
suffix (A.2.5.3). Unsuffixed literals make the expression double, so
`x * 2.0` costs milliseconds under A. If a measured workload needs faster doubles,
option B can replace the shim routines later without touching the compiler,
because the compiler only names `_fcc_d*` entry points in either design.

## 5. Increments, each gated

0. **Found-along-the-way defects** (section 2): `long double` parses (as
   `double`, which is float until increment 2), `?:` balances its arms,
   global float array initialisation, float `switch` rejected. Each gets its
   own fixture. No double yet.
1. **`long long`** in fcc: type, 8-byte transport (`_fcc_dacc`/`_fcc_dacc_b`,
   which double then shares), `+ - * / % << >> & | ^ ~`, compares and
   conversions, all as a runtime in fcc_runtime.s. Its own plan document,
   and its own fixtures against host results.
2. **Double type and storage.** `BT_DOUBLE`, sizeof 8, and load, store, push,
   pop and return on the long long transport. Copying a double is correct
   with no arithmetic. Every float and long path stays byte-identical.
   - **Spelled `long double` until the flip (2026-09-24).** df, od and libc's
     atof do double arithmetic and print doubles. If `double` became 8 bytes
     before increments 3, 4 and 6 exist, the tree would stop building.
     K&R A.4.2 (p.158) allows the interim: float, double and long double
     "may be synonymous, but the ones later in the list are at least as
     precise as those before".
   - So `long double` is the 64-bit type from this increment on, and every
     double fixture uses that spelling. `double` stays today's single until
     a final commit makes it the same type as `long double`, once
     arithmetic, promotion, constants and printf all exist.
   - Every commit builds the tree and passes the gate.
   - **The flip is done (2026-09-24).** `LT_DBL` is `LT_DOUBLE`, so `double`
     and `long double` are one type; an unsuffixed floating constant is the
     64-bit double and an F one the single (A.2.5.3).
   - Found by the flip and fixed with it: a `(void)` cast of a double called
     the double-to-long conversion (A.6.7 discards the value); a compound
     assignment statement with a 64-bit right operand took the narrow
     operator (A.7.17, `E1 = E1 op (E2)`); stores of a 64-bit value through
     the lvalue-store arms skipped the conversion to the target; and
     `ecvt` wrote an IEEE double's up to 309 integer digits off the front
     of its buffer.
   - Until increment 3, arithmetic, compares and conversions on the 64-bit
     type are refused with a message naming the increment. They are not
     miscompiled.
3. **Runtime.** Vendor `examples/65816-llvm-mos/runtime/src/softDouble.c`
   (with a PROVENANCE row) and compile it with fcc into the `_fcc_d*` entry
   points.
   - Fixtures: values single cannot represent (1+1e-9, 2^53-1,
     3.97e9 + 0.201), checked against the host's IEEE double.
   - The host bit-exact harness from 2026-09-23 is kept as the reference.
   - **Done (2026-09-24), on `long double`.** The `double` archive holds
     fcc's compile of `lib/libdouble/softdouble.c` and `d_glue.s`, entry
     points on the long long carrier's convention, so fcc reaches them as it
     reaches the llong runtime. Each call spills the live FPRs, since the
     glue calls compiled C.
   - Divergence, allowed by K&R: denormals flush to zero. Double to float
     rounds to nearest, ties to even (A.6.4 allows either neighbour), where
     the upstream soft double truncates, so a run-time conversion agrees
     with a static initializer's.
   - Not provided by the soft double, so refused: conversions between long
     long and long double.
4. **Promotion** per A.7.3.2: varargs and old-style calls, and K&R float
   parameters.
   - **Done (2026-09-24), keyed off `LT_DBL`**, the type `double` denotes
     (tword.h), `LT_DOUBLE` since the flip.
   - Caller: a float argument with no declared parameter (an old-style
     declaration, none, or past `...`) is converted to `LT_DBL`.
   - Callee: a float named in an old-style declaration list arrives as
     `LT_DBL` in its slot size, `Func.param_types`, its signature and the
     `--sigs` sidecar, and is narrowed to a float in the low bytes of the
     same slot on entry. A.10.1 (p.186) keeps its declared type, so `&x` is
     a `float *`.
   - `tests/M41/float_promote.c` was trivially green until the flip, and was
     checked before it with a candidate fcc built with `LT_DBL` as `LT_DOUBLE`, through
     `run_runtime.py --use-fcc`. The candidate must sit in `toolchain/`,
     since fcc finds `<stdarg.h>` at `dirname(argv[0])/include`. It passed,
     and three mutations failed it: no caller promotion (check 1), no
     narrowing (check 3), 4-byte slots (check 5).
5. **Constants and `<float.h>`.** Host `strtod` into 64 bits, the literal
   suffix kept, double static initializers.
   - **Constants done (2026-09-24), on `long double`.** A.2.5.3: "L or l
     makes it long double". An L constant carries its strtod value as 64
     bits; an unsuffixed one is still the single. Static initializers of a
     long double scalar, static local, array (flat, nested, unsized) and
     struct member take a floating, integer or character constant, with an
     optional minus. An unsuffixed floating constant initializes to the
     single widened exactly, the value a run-time assignment stores.
     Fixture `tests/M41/ldouble_const.c`.
   - Static-local arrays of long double stay refused, as float and long
     ones are: that path takes only char, int and char * elements.
   - **`<float.h>` done at the flip**, from 4.3BSD-Reno's IEEE
     `hp300/float.h` (7.1 5/8/90, vendored; 2.11BSD has none). `FLT_ROUNDS`
     1 holds once the soft double's double-to-float rounds to nearest.
     `DBL_MIN` and `DBL_MAX` take NetBSD 0.9 i386's 17 digits: Reno's 16
     read past the largest double and below the smallest normal one.
6. **libc.** printf `%e/%f/%g` and `atof`/`strtod` at double, from 2.11BSD's
   own libc if it has a portable form, otherwise SANE's decimal routines.
   od and df audited.
   - **Done (2026-09-24).** The soft double lives in the fpsim module
     (`2026-09-24-fpsim-module-plan.md`).
   - printf's float output is libc member `fltpr.c`, loaded as 2.11BSD's
     `fltpr.s` is: fcc marks a program that passes a float where no
     parameter is declared, and without the mark printf prints `?'
     (`ffltpr.s`).
   - Its digits are 2.11BSD's `ecvt.c`, its layout K&R B.1.2.
   - `atof` is 4.3BSD-Reno's IEEE hp300 copy. `modf` and `ldexp` derive from
     llvm-mos `math.c`.
   - All of them work on long double inside a double interface, so they are
     64-bit now and need no change at the flip.
   - df, frotz and od load the printer; tcsh does not.
   - scanf(3), fscanf(3) and sscanf(3) are 2.11BSD's `doscan.c` and
     `scanf.c` (2026-09-24), reading a double with `%le`/`%lf`/`%lg` through
     `atof`. `%g` and the `L` prefix are added per K&R B.1.3; `%i`, `%n` and
     `%p` are not carried, as upstream has none. FGX has no `strtod`, and
     2.11BSD has none either.
7. **The ntp model from the issue**, rerun on FGX: offset and delay errors of
   0 where single gave 166 s and 256 s.
   - **Done (2026-09-24).** `tests/M41/ntp_model.c` carries 2.11BSD ntp.c's
     delay and offset arithmetic (`ntp.c:303-320`) and `ul_fixed_to_double`
     (`ntpsubs.c:67`) over a 90 s offset and a 0.201 s round trip, the send
     time swept across 256 s near 3.97e9. On FGX both errors stay within
     1 microsecond, ntp.c's `%f` resolution.
   - The same fixture with `double` spelled `float` fails on FGX, and on the
     host the single version's worst offset error is 166 s.

Each increment goes through goldens (`REGEN=1` checked to move only intended
files), the runtime oracle, and `tools/gate.sh`. The tree-impact method
applies: replay every `toolchain/fcc` command with the old and new compiler
and diff the `.s`.

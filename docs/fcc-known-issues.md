# fcc known issues and limits

The open gaps and hard limits of `fcc`, FGX's K&R C compiler
(`toolchain/src/cc/`). Consult it before scoping a port; `docs/userland-bsd-ports.md`
routes here. Defects are filed in the issue tracker; this page lists what a porter runs
into.

fcc implements K&R 2nd edition Appendix A with 16-bit `int`, plus the ANSI
conveniences listed in `toolchain/README.md`. It mostly **fails closed**: an
unsupported construct is normally a compile-time `error:`, not a silent
miscompile, so "build it and read the errors" is the way to find out what a
port needs. The one known silent exception is the absolute-address pointer
initializer in the table below. Per
the toolchain-first rule (`docs/developing-userland.md`), a gap a port hits is
fixed in fcc with a fixture under `toolchain/tests/M*/`, not worked around in
the port.

Rebuild: `make -C toolchain`. Fixtures: `bash toolchain/tests/run.sh`
(`REGEN=1` rewrites the goldens).

## Open gaps

Each was reproduced against the current fcc with the probe shown. All but the
last fail closed with the message quoted.

| Gap | Probe | fcc says |
|-----|-------|----------|
| `#` (stringize) and `##` (paste) preprocessor operators | `#define S(x) #x` | `unexpected character # (0x23)` |
| A function returning a `struct`/`union` by value | `struct s f() { return g; }` | `return-by-value struct not supported (M8); use a pointer parameter` |
| Multi-dimensional arrays of `struct` | `struct p grid[3][4];` | `multi-dim arrays of struct not supported (M19)` |
| A nested aggregate in a local initializer | `struct l v = {{1,2},3};` (local) | `nested aggregate in local struct initializer not supported` |
| More than 8 parameters in a function-like macro | `#define M(a,b,c,d,e,f,g,h,i) a` | `too many params in function-like #define (max 8)` |
| A call with more arguments than an OLD-STYLE declaration or definition in the source has parameters (K&R A.7.3.2: undefined, not an error; fcc does not record old- versus new-style, so it treats it as a prototype mismatch).  A signature from `--sigs` only warns | `f(a) int a; {}` then `f(1, 2);` | `'f' expects 1 argument, got 2` |
| A pointer array or struct field initialised from an absolute address is refused | `char *a[] = { (char *)0xE12000L };`, `struct s v = { (char *)0xE12000L };` | a diagnostic (`char*[] init item must be ...`, `char* field init: need ...`): it fails closed.  K&R A.7.19 allows the constant; a scalar file-scope pointer takes it whole since apple/fgx#532 |

By design rather than gaps (K&R behaviour, `toolchain/README.md`):
`__STDC__` is not defined; macro parameters are substituted inside character
and string literals; `const`/`volatile`/`register`/`auto` are parsed and
discarded. C99 constructs (designated initializers, compound literals,
declarations in `for`) are out of scope.

Recorded but not re-verified for this revision: a self-referential macro
passed as a function-like macro's argument can expand one level further than
cpp's "blue paint" rule allows (fcc keeps no persistent no-expand marks), and a
guard-blocked self-recursive function-like call drops its arguments where cpp
would emit them as plain tokens. Argument pre-expansion itself is pinned by
`toolchain/tests/M36/pp_adv3.c`.

## Struct layout

Structs follow the PDP-11 / 2.11BSD layout: `char` members are byte-packed,
every wider member (`short`, `int`, `long`, `float`, pointer) is at an even
offset, and the total is rounded up to even (pinned by
`toolchain/tests/M32/charpack.c`). A wire format with a word member at an odd
offset therefore cannot be expressed as an fcc struct and has to be handled as a
byte buffer.

## Capacity limits

Hard limits, each a compile-time `die` when exceeded. Values from
`toolchain/src/cc/fcc.h` unless noted.

| Limit | Max | Constant |
|-------|-----|----------|
| structs/unions per TU | 512 | `MAX_STRUCTS` |
| fields per struct | 256 | `MAX_FIELDS_PER_STRUCT` |
| locals per function | 512 | `MAX_LOCALS` |
| `static` locals per function | 32 | `MAX_STATIC_ALIASES` |
| `goto` labels per function | 256 | `MAX_USER_LABELS` |
| cases per `switch` | 1024 | `MAX_CASES_PER_SWITCH` |
| nested `switch` | 32 | `MAX_SWITCH_NESTING` |
| nested loops/switches | 32 | `MAX_LOOP_CTX` |
| enum constants per TU | 512 | `MAX_ENUM_CONSTS` |
| distinct function-pointer signatures per TU | 512 | `MAX_FN_SIGS` |
| identifier length | 64 | `MAX_IDENT` |
| array dimensions | 12 | `MAX_DIMS` |
| pointer derivation depth (`*` levels) | 8 | `TW_MAX_DERIV` (`tword.h`) |
| brace-initializer values per object | 2048 | `MAX_INIT_VALUES` |
| leaves in a struct initializer | 96 | `MAX_STRUCT_INIT_LEAVES` |
| string literal length | 4096 | `MAX_STR_TOK_LEN` |
| `#include` depth | 16 | `PP_MAX_INCLUDE_DEPTH` |
| `#if` nesting | 16 | `PP_MAX_COND_DEPTH` |
| function-like macro parameters | 8 | `PP_MAX_FN_PARAMS` |
| macro body length | 2048 | `PP_MAX_MACRO_BODY` |
| AST nodes per function | 65536 | `MAX_AST_NODES` |

File-scope variables, typedefs and string literals have no fixed cap
(`g_globals`, `g_typedefs` and `g_str_lits` grow with `FCC_GROW`).

## Closed gaps a porter may have read about

| Gap | State | Proof |
|-----|-------|-------|
| Single translation unit (no cross-`.c` link) | Separate compilation works: `tools/ninja/gen.py` (`direct_link_edges`) compiles each TU listed in a tool's `tu_list` with its own fcc edge, and `fgx_ld.py` resolves the references (`extern` data by name, calls by `FGX2_FARCALL`). | 16 manifest tools use `tu_list`, sh, tcsh and elvis among them; `ls` is upstream's two files (`src/userland/ls/tu.list`: `stat_flags.c`) |
| K&R function definitions | Native dialect | `toolchain/tests/M28/f_knr.c` |
| Unsigned semantics, and the K&R A.2.5.1 integer-constant type ladder (hex `0x8000` is `unsigned int`) | Done | `toolchain/tests/M34/u_track.c`, `toolchain/tests/M23/int_const_ladder.c` |
| `char` struct members took 2 bytes | Byte-packed | `toolchain/tests/M32/charpack.c` |
| Pointer arithmetic on `struct T **` scaled by 2 | Fixed | `toolchain/tests/M37/ppstride.c` |
| `long`/`float` compound assignment dropped the high word | Fixed | `toolchain/tests/M37/longcompound.c` |
| `main`'s `argv` | A real 4-byte `char **` bound to `args_argv` (`parse_stmt.c`) | -- |

Constructs that older notes listed as rejected and that compile today:
`(*pp)->field`, `p[i].field = x`, file-scope prototype lists
(`char *a(), *b();`), `void (*)(void)` and initialised function-pointer locals
and globals, local arrays of pointers, struct assignment, chained assignment,
`long` `/` and `%`, `long long`, array dimensions that are constant
expressions, and `static struct` locals with initializers.

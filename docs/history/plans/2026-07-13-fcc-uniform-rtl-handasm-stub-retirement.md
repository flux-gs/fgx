# Scoping: retire hand-asm syscall stubs → make fcc uniformly right-to-left

**Date:** 2026-07-13
**Status:** SCOPING (design only — no code)
**Sibling:** `2026-07-12-fcc-ld-bsd-alignment-scoping.md` (weak libc symbols). Related
theme — both align fcc with the K&R/2.11BSD paradigm — but independently landable.
**Trigger:** the elvis `ttyread` bug. fcc has TWO calling conventions and the seam
between them silently reverses args. 2.11BSD (and every K&R compiler) has ONE
convention — uniformly right-to-left — so the bug class cannot exist there.

---

## 1. The problem, precisely

fcc pushes/reads C arguments in **two** orders:
- **L-to-R** — default, for ANSI-prototyped fixed-arity functions. Chosen so
  fcc-emitted code agrees with FGX's **hand-asm syscall stubs, which read args
  L-to-R** (`parse_stmt.c:4324`; and `:4337` records that a past "universal flip"
  to R-to-L was reverted *because* it broke those stubs).
- **R-to-L** — retrofitted only for empty-paren `()` / `...` functions, to make
  K&R varargs work.

A K&R-style **definition** defaults to L-to-R **unless its own TU has seen an
empty-paren declaration of it** — a fragile, accidental condition. When a K&R
definition is L-to-R but its callers (via an empty-paren prototype) push R-to-L,
every arg is reversed. That is the elvis `ttyread` bug (`unix.c` had no `#include`,
so its definition never saw the prototype). It is latent in **every** K&R shim that
forgets to include its own header.

**2.11BSD never hits this**: pre-ANSI C has no prototypes, so there is exactly one
convention (R-to-L) for every call and every definition — caller and callee cannot
disagree. The fix is to make fcc the same: **uniformly R-to-L.**

## 2. Why this is now unblocked

fcc is L-to-R *only* to match hand-asm that reads C args L-to-R. The **libc shims
proper are already gone** — `fcc_libc_shims.s` is a graveyard of "CONVERTED TO C"
markers; the real code is in `libc_c.s`, which fcc **compiles**, so it is
self-consistent with whichever order fcc picks. What remains reading C args in asm:

| Boundary | Count | Arg-order-sensitive? |
|---|---|---|
| per-tool `src/userland/*/*_stubs.s` | 25 files | **13** are multi-arg (read `6,S`+) |
| `crt0*.s` → `main(argc,argv)` | 4 files | **NO** — bare `JSR main`; params magic-bound to `args_argc`/`args_argv` globals (parse_stmt.c:4397-4468), auto-flip-consistent |
| `libc.s` hand-asm `printf`/`fprintf`/`sprintf` | 3 | dead dupes of C `c_printf…` |
| `setjmp`/`longjmp` (fcc builtins) | 2 | NO — **register ABI** (X=jmp_buf, A=val), read no stack C args |
| kernel syscall handlers + signal delivery | — | NO — register ABI (A/X/Y); `_sig_tramp` pushes exactly ONE arg to the C handler (crt0_far.s:417) |

**The true blocker set** (corrected after review — the naive "6" undercounted): the
**13 multi-arg stub files** + the dead `libc.s` printf trio. `crt0`→`main` is a
**verify-only no-op** (fcc binds main's params to globals, not a pushed frame). No
asm→C multi-arg call site exists anywhere else in the tree (signal tramp is 1-arg;
no C in kernel/modules/drivers; `fcc_runtime.s`/`args.s` have zero `n,S` C-arg reads).

The 13 multi-arg stubs (read a 2nd arg): `jsh`, `cwdtest`, `cwdkid`, `pipetest`,
`ttytest`, `tchtest`, `waittest`, `kill`, `killtest`, `duptest`, `pgrptest`,
`stopper`, `ps`. Their tool-specific syscalls: spawn/spawnx/spawnve, pipe, dup/dup2,
sendsig, procs, listdir. The rest are `_`-suffixed **private duplicates of libc
syscalls** (kill/ioctl/chdir/open/waitpid/getcwd/setpgid), named `_` solely to dodge
fcc's libc-binding table (the `getkey`→`c_getkey` shadowing this session opened with).

**CARVE-OUT:** `ntpplay_stubs.s` (93 KB) is NOT syscall glue — it is the sanctioned
asm DOC-IRQ playback engine. Its `eng_*` entries are all **zero-arg** (globals-based
interface, flip-immune), so it does not gate the flip and must NOT be deleted.

## 3. Target end state

- All per-tool syscall glue lives in **shared libc as C** over the syscall
  trampoline (`SYS_TRAMP`). No tool rolls its own asm wrapper. `jsh` becomes pure C;
  `jsh_stubs.s` (and the other 24) are deleted.
- `libc.s`'s dead `printf` trio deleted (C `c_printf…` already exist).
- **fcc emits and reads all args R-to-L, universally** — the `is_variadic_expl`
  *ordering* distinction disappears (varargs was already R-to-L; fixed-arity joins
  it). One convention, K&R/2.11BSD-shaped.
- `crt0` pushes `main`'s `argc`/`argv` R-to-L to match.

Result: the two-convention seam is gone. The whole arg-order bug class dies
permanently — a future K&R shim that forgets its `#include` (the `ttyread` trap)
can no longer be miscompiled, because L-to-R no longer exists.

## 4. The fcc change — NOT one knob (must decouple `is_variadic_expl`'s two jobs)

Review finding: `is_variadic_expl` currently means TWO things — (a) arg **ordering**
(R-to-L) and (b) **"this is varargs"** (drives va_arg slot-walk marshalling AND a
by-value-struct reject). Making ordering universal must NOT also make everything look
varargs. Concretely:

- **Ordering, def side:** `parse_stmt.c:4340` `int flip = is_variadic_expl` → always
  flip. Introduce a distinct predicate (e.g. `g_rtl_universal`) for ORDER, leaving
  `is_variadic_expl` to mean varargs only.
- **Ordering, call side:** there are **FOUR** `rtl_begin` sites — three fn-pointer
  calls keyed on `g_fn_sigs[].is_variadic` (parse_expr.c:3377/3487/3690) plus
  `N_CALL_NAMED` at 3534 (with the `lb->is_variadic` libc-binding branch). **All
  four** must go order-active, not just the `is_variadic_expl` one.
- **★ Blocker — `rtl_finish` struct-by-value `die()`** (parse_expr.c:213): it dies on
  `active && has_struct`. Today `active`=varargs-only, so a universal flip would make
  **every fixed-arity struct-by-value call fail to compile** — a supported,
  golden-tested construct (`tests/multibank/c25_structarg.c`, MVN copy path). The
  guard exists for the varargs va_arg walk, so it must key off the varargs meaning,
  NOT the (now-universal) ordering. Decouple before flipping.
- **Arg EVALUATION order:** `walk_call_args` evaluates arg subtrees in reverse when
  rtl is active (T5-C C5). A universal flip reverses **observable side-effect order
  for every multi-arg call corpus-wide** (see §7 risk). Legal C; K&R/PCC was R-to-L
  so 2.11BSD ports are historically safe, but FGX-original C written under L-to-R
  could harbor order dependencies.
- The L-to-R layout/eval code becomes dead (remove after the flip proves out).

Because fcc controls both call and definition sites for all C code, ordering is
**transparent for every fcc↔fcc call** — only the (now-eliminated) hand-asm
boundaries could disagree. That is why Phase 1 (retire the stubs) must precede
Phase 3 (the flip).

## 5. Phasing (each phase independently green)

- **Phase 0 — boundary audit.** Grep EVERY hand-asm `.s` for a C-arg read (`6,S`+ =
  2nd arg; note a far-ptr 1st arg spans `4,S`+`6,S`, so filter by an arg-2 read).
  Confirmed set: **13 multi-arg stubs** (§2) + dead printf trio; crt0→main is a
  no-op; ntpplay_stubs.s carved out. Classify each syscall: already-in-libc (binding
  table already routes kill/pipe/dup/dup2/waitpid/getcwd/ioctl/chdir/open/spawnv*)
  vs must-add (spawnx, sendsig, procs, listdir). **Verify `globals.c:229` `c_kill`
  "WIP STUB: no-op"** is stale before routing jsh through libc kill — if live, real
  kill/signal semantics must land first.
- **Phase 1 — hoist syscalls into libc (C).** Add C wrappers over `SYS_TRAMP` for the
  must-add syscalls; route the `_`-dupes to existing libc functions (binding table
  already intercepts the plain names, so the weak-symbol scope does NOT block this).
  Convert the 13 multi-arg tools to call libc; delete their `*_stubs.s`. (The ~11
  single-arg stubs are order-agnostic — retire lazily.) Retire the dead `libc.s`
  printf trio. Green: all tools link+run on the STILL-L-to-R fcc.
- **Phase 2 — crt0 = VERIFY-ONLY (no-op).** Review confirmed no crt0 pushes
  argc/argv; fcc magic-binds main's params to `args_argc`/`args_argv` globals through
  the same Local records the flip recomputes — automatically consistent. One 2-arg
  `main` fixture confirms; no crt0 edit expected.
- **Phase 3 — flip fcc to uniform R-to-L.** Decoupled ordering predicate (§4) + all
  four `rtl_begin` sites active + struct-by-value guard re-keyed to varargs-only.
  **Regenerate the checked-in `toolchain/lib/libc_c.s` (`make libc_c`)** — MANDATORY:
  without it, R-to-L tools call a stale L-to-R libc and every multi-arg libc call is
  reversed. Then full `REGEN=1 tests/run.sh` (every golden changes — expected) + full
  runtime oracle sweep (the real gate) + `stack_check`. Blocker set from Phase 0/1 is
  empty, so the `:4337` landmine cannot fire.
- **Phase 4 — cleanup + validate.** Delete dead L-to-R codegen. Rebuild elvis: the
  `unix.c`-missing-include case is now *safe by construction* (revert the manual
  `int ttyread();` shim added 2026-07-13 and confirm it still works). MULTIBANK_VERIFIED
  run (arg-marshalling path changed). Whole-userland runtime sweep.

## 6. Dependencies & relationship to the weak-symbol scope

- The `_`-suffix dodging is a **libc-binding-table** artifact. To have tools call
  libc's `kill`/`ioctl`/`chdir`/… directly (dropping the `_`), the binding table
  must let a plain-named libc call resolve — i.e. the **weak-symbol / plain-name
  fix** from `2026-07-12-fcc-ld-bsd-alignment-scoping.md`. So: land the weak-symbol
  fix first (or in the same train) to let Phase 1 use real libc names; otherwise
  Phase 1 keeps distinct wrapper names (still fine, just less clean).
- The two scopes share the theme "align fcc with K&R/BSD" and a shared **full
  golden regen**; batching them into one toolchain train saves one regen cycle.

## 7. Risk & payoff

The three residual risks all live in **fcc/build plumbing**, NOT in hand-asm — so
Phase 0's grep-for-`n,S` methodology would NOT surface them (review finding):
- **★ Struct-by-value compile break** (§4): `rtl_finish` `die()` on `active &&
  has_struct`. Must re-key the guard to varargs-only before flipping, else golden
  `c25_structarg.c` fails to compile. This is the single most likely way to break
  the build.
- **★ Stale checked-in `libc_c.s`** (§Phase 3): must `make libc_c` in the SAME
  commit as the flip. Per-tool `src/userland/*.s` listings are stale but harmless
  (`build_userbin_fgx2_c` recompiles from `.c`); `libc_c.s` is checked in and linked
  as-is → reversed libc args if not regenerated.
- **Arg evaluation-order reversal, corpus-wide**: every multi-arg call's observable
  side-effect order flips. Legal C; 2.11BSD ports safe (PCC was R-to-L); FGX-original
  C is the exposure. The runtime sweep is the net, but this is a behavior change to
  call out, not just a codegen one.
- **Missed hand-asm boundary**: LOW — review confirmed the only asm→C multi-arg seam
  in the tree is none (signal tramp is 1-arg; crt0 is a no-op; runtime/args have zero
  `n,S` C reads). The historical `:4337` pain was *because the blocker set was
  unnamed*; naming it (this doc) is what makes the flip safe.
- **Payoff**: the entire arg-order class is deleted, not patched. Every future K&R
  port/shim is safe. fcc becomes honestly K&R. `jsh` and the tool suite become pure
  C (no per-tool asm), advancing the standing "no hand-asm / libc-in-C" goal.

## 8. Non-goals

- Does **not** fix elvis's remaining non-arg-order bugs (the `72:$306x` `i`-hang
  loop, the ~6 s slow render). Those are a separate elvis track.
- Does **not** remove `setjmp`/`longjmp`/`crt0`/the syscall trampoline from asm —
  those are legitimately asm; they are just made order-agnostic or R-to-L-aware.

## 9. Open questions for the maintainer

1. **Batch with the weak-symbol scope?** One combined toolchain train (shared regen)
   vs two sequential. Recommend combined — they're the same paradigm shift.
2. **Retire all 25 stubs, or just the 6 multi-arg blockers?** The 19 single-arg are
   order-agnostic. Recommend retiring all 25 for the "no per-tool asm" endgame, but
   only the 6 gate the flip — the rest can trail.
3. **jsh first?** It's a multi-arg blocker AND the highest-value conversion (pure-C
   shell). Recommend jsh leads Phase 1 as the proof case.

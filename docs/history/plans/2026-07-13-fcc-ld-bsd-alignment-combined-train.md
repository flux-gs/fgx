# Combined train: fcc/ld → K&R/BSD alignment (Scopes A + B, one release)

**Date:** 2026-07-13
**Status:** EXECUTION PLAN (orchestration; the two scope docs hold the design detail)
**Orchestrates:**
- **Scope A** — `2026-07-12-fcc-ld-bsd-alignment-scoping.md` — archive-style link-time
  symbol resolution (weak/strong; drop the `c_` binding table + prefix). *The linker
  work.*
- **Scope B** — `2026-07-13-fcc-uniform-rtl-handasm-stub-retirement.md` — uniform
  R-to-L calling convention + retire the per-tool hand-asm syscall stubs. *The ABI
  work.*

**Thesis:** one program, two axes. A fixes *which definition a name binds to*
(resolution); B fixes *how args are passed* (ABI). They meet at one surface — the
libc export table — so shipping them together writes that surface **once**,
regenerates **once**, and retires every session-one stopgap **together**.

---

## 0. Standing constraints (from FGX discipline)

- **Campaign hold** — no release until the userland-port campaign closes; this train
  lands to LOCAL main and stays there until the maintainer green-lights the discharge.
- **Toolchain-first** — the toolchain repo releases first, THEN FGX re-pins the
  submodule. Never push a feature branch.
- **Regen discipline (critical):** `toolchain/lib/libc_c.s` is CHECKED IN and LINKED.
  It must be regenerated (`make libc_c`) after **every** fcc codegen change or the
  runtime links a stale pile. The **golden** fixtures (`.expected.*`) are test-only
  and their `REGEN=1 tests/run.sh` is deferred to Stage F — the RUNTIME oracle
  (exit-code vs `oracle.json`, no regen needed) is the per-stage green gate.
- `MULTIBANK_VERIFIED=1` run required at Stage F (both A and B change bank/arg
  emission).

## 1. Stage sequence

Order: **shared audit → A (resolution) → B (ABI) → finalize → re-pin.** A precedes B
because B's clean form (tools calling plain libc names, stubs deleted) depends on A's
plain-name resolution. Each stage lands as its own commit(s) on the train branch and
is RUNTIME-green before the next starts — single-regen economy, still bisectable.

### Stage 0 — Shared audit (no code)
One pass that feeds both scopes:
- **B boundary audit** — every hand-asm `.s` reading a C arg (`6,S`+). Confirmed set:
  13 multi-arg `*_stubs.s`; crt0→main is a no-op; `ntpplay_stubs.s` carved out; dead
  `libc.s` printf trio. (Scope B §2.)
- **A collision census** — every userland `.c` defining a libc-table name; the ABI
  decl-audit (empty-paren externs / undeclared variadic calls). (Scope A §7 Phase 0.)
- **★ Cross-cutting gate — WIP libc implementations.** `globals.c:229 c_kill` is
  annotated "WIP STUB: no-op". Verify which binding-table targets are real vs stub.
  Any stub a Stage-B tool must route through (kill/pipe/dup/waitpid/…) needs a REAL
  implementation first — this gates the jsh conversion independent of A.
- Output: the definitive boundary + collision + WIP lists. Nothing may be missed —
  a missed boundary is a silent arg/symbol corruption after the flips.

### Stage A — Linker resolution (Scope A Phases 1→3)
1. **A1 (inert):** add weak(LIBC-seg)/strong(any other seg) precedence to fgx_ld's
   FARCALL + LONG_PTR resolvers. Land 3 fixtures (user-wins / dup-strong-error /
   pile-fallback). Behavior unchanged while `c_` names still emitted. `fgx_ld` unit +
   runtime green.
2. **A2 (atomic fcc + pile):** pile exports plain names (rename `c_*`→plain in
   `libc_c.c`; retire hand-asm printf trio); delete the fcc binding table + the
   temporary getkey override + the `lb` emit branch → fcc emits plain
   `FGX2_FARCALL <name>`; the weak rule engages. **`make libc_c`** (runtime-critical).
   Runtime oracle sweep green; `getkey_shadow` fixture passes with the table gone.
- **Retires here:** the `c_` prefix, the compile-time binding table, the getkey
  arity-override stopgap.

### Stage B — ABI + stub retirement (Scope B Phases 1→3)
1. **B1 (stubs → libc, on plain names):** hoist the tool-specific syscalls
   (spawn/spawnx/spawnve, pipe, dup/dup2, sendsig, procs, listdir) into shared libc as
   plain C wrappers over `SYS_TRAMP`; route the `_`-dupes to the now-plain libc
   functions (A made this safe). Convert the 13 multi-arg tools; delete their
   `*_stubs.s`. **`make libc_c`.** Runtime green on the STILL-L-to-R fcc. jsh leads as
   the proof case (pure-C shell).
2. **B2 (decouple + flip):** split `is_variadic_expl`'s two jobs — introduce an
   ordering predicate distinct from the varargs meaning; re-key `rtl_finish`'s
   struct-by-value `die()` to varargs-only (else golden `c25_structarg.c` won't
   compile); activate **all four** `rtl_begin` sites; flip def-side layout universal.
   **`make libc_c`** (pile now R-to-L). Runtime oracle sweep green.
- **Retires here:** the two-convention seam, the per-tool asm stubs, the reason the
  elvis `unix.c` ttyread prototype hack existed.

### Stage F — Finalize & validate (one regen, the real gate)
- One `make libc_c` (confirm clean) + **full `REGEN=1 tests/run.sh`** (every golden
  changes — expected from both A rename and B flip) + **full runtime oracle sweep** +
  `stack_check` (0 violations) + **`MULTIBANK_VERIFIED=1`** run.
- **elvis regression:** rebuild; REVERT the manual `int ttyread();` in
  `src/userland/elvis/unix.c` and confirm it still paints + blocks (uniform R-to-L
  makes the omitted-prototype case safe by construction). The `72:$306x` i-hang is
  OUT OF SCOPE (separate elvis track) — note, don't chase.
- Whole-userland runtime sweep: every shipped binary exits its oracle code; no
  unresolved/ambiguous link errors; no arg-order regressions.

### Stage R — Release & re-pin
- Toolchain: merge the train to LOCAL toolchain main (`--no-ff`, `pre-` tag), version
  bump per `release.sh` when the maintainer green-lights the discharge.
- FGX: re-pin the submodule; merge to LOCAL FGX main. UNRELEASED under campaign hold
  until the discharge train.

## 2. Written-once surface (why combine)

The libc export table is edited by BOTH scopes. Combined, each function is authored
in its FINAL form — plain-named (A) *and* R-to-L (B) — instead of twice:
- A renames `c_getkey`→`getkey` (weak); B's new `spawn`/`pipe`/… are born plain-named,
  never needing a `c_` form.
- `libc_c.s` regenerates after A2, B1, B2 (runtime), but the **golden** fixtures
  regenerate ONCE at Stage F — halving the expensive full-corpus regen vs two trains.

## 3. Stopgaps this train retires (all from this session)
- getkey libc-binding arity-override (`g_libc_user_overrides`) → subsumed by A's
  weak/strong resolution.
- elvis `unix.c` `int ttyread();` prototype hack → unnecessary under B's uniform
  R-to-L (Stage F reverts + verifies).
- The `c_` prefix, the compile-time binding table, the per-tool `*_stubs.s`, the dead
  `libc.s` printf trio, the L-to-R/R-to-L seam.

## 4. Risk & rollback

- **Bisectable-by-stage:** each stage is its own commit(s), RUNTIME-green before the
  next. If Stage F's golden regen surfaces a fault, the runtime sweeps at A2/B1/B2
  localize which axis introduced it.
- **Highest residual risks (Scope B §7, fcc/build plumbing — invisible to the
  hand-asm audit):** (1) the struct-by-value `die()` decoupling (B2) — most likely
  build-breaker; (2) stale checked-in `libc_c.s` — mitigated by the per-stage
  `make libc_c` discipline; (3) corpus-wide arg-EVALUATION-order reversal — a behavior
  change (legal C; 2.11BSD ports safe, FGX-original C is the exposure).
- **Scope A residual (§6):** split-brain heap if a program overrides malloc/free
  (pile is prebound) — accepted limitation; the Stage-0 census flags any userland
  malloc/free override.
- **Rollback unit** = a stage. A2 and B2 are the irreversible-ish fcc-codegen commits;
  keep A1/B1 (additive) landed even if a later stage reverts.

## 5. Definition of done
- fcc emits plain names, R-to-L, uniformly; no binding table; no `c_` prefix.
- fgx_ld resolves strong(user) over weak(pile); user defs win at link time.
- No per-tool hand-asm syscall stubs; jsh + tool suite are pure C.
- Full golden + runtime + multibank green; elvis paints/blocks WITHOUT the ttyread
  hack.
- Toolchain merged to local main, FGX re-pinned; both UNRELEASED under campaign hold.

## 6. Open questions for the maintainer
1. **jsh conversion gate:** confirm real kill/signal (and the other routed syscalls)
   before Stage B1 routes jsh through libc — or hold jsh for last within B1?
2. **Discharge timing:** land this train fully local now, release with the userland
   campaign discharge — or checkpoint-release the toolchain after Stage A (the linker
   weak/strong is independently useful)?
3. **Version bumps:** one combined toolchain minor (both axes) vs two — recommend one,
   since the golden surface moves once.

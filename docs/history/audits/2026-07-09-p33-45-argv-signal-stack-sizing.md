# P3-3 #45 — argv frame + signal-handler stack sizing (CLOSURE)

> **RELEASE HOLD** — all work LOCAL/committed on toolchain
> `feat/p33-soft-stack-delete` + FGX `feat/p33-soft-stack-delete-fgx`.
> No push / release.sh / merge / tags / submodule bump until the maintainer green-lights.

Follow-up to #42 (pad calibration).  #42 kept `DEFAULT_PAD` / `FCC_STK_FLOOR_MARGIN`
at 128 and flagged two stack consumers the pad silently shares but no constant can
fix, because both are STRUCTURAL (top-side / async, invisible to `worst=depth(main)`):

- **(A) argv/envp frame** — the kernel lays a BSD-shaped argv/envp frame on TOP of
  the child's stack at posix_spawn; crt0 copies the strings into `args_input` and
  PRESERVES S (crt0_far.s:136), so the frame permanently occupies the top `T` bytes.
  The linker never sees `T` (command-line-dependent), so it competes with the C
  stack + pad on a 1-page tool.  Old E2BIG check ran AFTER the frame was written
  (loader.s tail) — an oversized frame had already scribbled below StackBase.
- **(B) signal-handler subtree** — a handler registered via signal()/sigaction()
  runs its C subtree on top of the interrupted frame at delivery, invisible to
  `worst=depth(main)`; an UNGUARDED small-frame handler skips the prologue STKGUARD.

## Fix A — argv/envp frame sizing (kernel)

1. **`_Loader_MeasureArgs` / `_Loader_ArgsExtraPages` (loader.s)** — walk the caller's
   argv/envp exactly as `_Loader_StageArgs` will (same per-string 128-cap via the
   factored `_la_measureStr`), computing `T = 4(resume)+2(argc)+2(argv NULL)+
   2(envp NULL) + Σ(min(strlen,128)+1 +2 ptr slot)`.  `ArgsExtraPages` returns
   `ceil(T/256)`.
2. **posix_spawn (process.s)** — `pages = max(hint,1) + ceil(T/256)`.  Normalize the
   hint 0→1 BEFORE adding (else a 0 hint + extra skips the default C page).  Over the
   [1,32] clamp the frame still won't fit → the loader's pre-write gate returns E2BIG.
3. **Pre-write E2BIG gate (loader.s `_Loader_StageArgs`)** — before Pass 1 writes a
   byte: `JSR _Loader_MeasureArgs`; require `TCB_StackSize - FCC_STK_FLOOR_MARGIN >= T`
   (i.e. saved_S ≥ StackBase+MARGIN), else E2BIG.  The old tail check is kept as a
   defensive assertion (can only fire if MeasureArgs and the laid frame ever diverge).

Cost: every spawn gets ≥+1 page (argv[0] alone makes T>0).  Accepted — safe direction,
the finding's specified design (`ceil(T/256)`), and cheap on FGX's 112-page arena.
Upgrade path (avoids the universal +1): store worst_C in the header so spawn can
compute the ceil-slack and only add pages for `T > slack`; deferred (header change).

## Fix B — signal-handler subtree

- **B1' sizing allowance (stack_measure.py)** — `SIGNAL_RE` detects
  `FGX2_FARCALL c_signal|c_sigaction`; when present (and not floored) add
  `signal_extra = edge_overhead + maxfn` to `total`, ADDITIVE to `indirect_extra`
  (a signal can fire while an fn-ptr subtree is live).  `maxfn` is the deepest subtree
  over ALL non-entry fns, so it already upper-bounds any single handler's subtree —
  the allowance is as precise as a one-hop model can be.  Unit test added.
- **B2 crt0 trampoline hard-floor tripwire (crt0_far.s `_sig_tramp`)** — before
  dispatching the C handler, `TSC / ADC #128-6 / CMP _fcc_stkfloor / BCC → JMP
  _fcc_stkoflow`.  Traps LOUDLY (exit 134) iff `S < StackBase` (= `_fcc_stkfloor-128`),
  NOT `S < floor`.  **Fable-reviewed threshold**: the pad region [StackBase, floor)
  is LEGAL for non-C users (this trampoline, IRQ/shim pushes), so a floor compare
  would false-trap a normal signal delivered at deep C depth; StackBase is the only
  line the pad contract guarantees is never legally crossed.  `-6` also covers the 6
  dispatch bytes still to be pushed.  Backstops B1' for a nested/unguarded handler
  overrun; cannot see the subtree's future depth (honest tripwire, not an oracle).

## Investigation notes (the long way round)

- **stkfloor 134→42 regression was REAL and CORRECT.** Fix A gives a spawned
  `/tests/fcc/stkfloor` (argv[0]=19 chars, envp NULL → T≈32) `1+1 = 2` pages.  The
  fixture's 252 B `big()` frame no longer crosses the floor on 2 pages.  Resized
  `big()` to `pad[210] = 420 B` (window (352, 480): crosses the 2-page floor,
  stays in-bounds in the unseeded RED case).  Golden regenerated.
- **The trap was masked by a STALE GOLDEN.** `run_runtime.py` default mode stages
  the `.expected.bin` GOLDEN, not a fresh compile of the `.c` — changing stkfloor.c
  without `REGEN=1 ./run.sh` ran the old 252 B binary.  A `stack_excursion` probe on
  the fcc_runtime disk proved the geometry was right (min_s consumed only ~276 B =
  the 252 B binary); regenerating the golden fixed it → 134.
- **Fix A's extra page is DIRECTLY proven** by the probe: the spawned tool's S
  reached base+494, which EXCEEDS a 1-page top (base+256) — impossible without Fix A.
- **`stack_excursion` max_s is NOT a reliable saved_S proxy** (it samples a steady-
  state S, not entry S: identical base+494 across T≈32/75 workloads).  The corruption
  oracle is `min_s >= StackBase` (the tap captures S across the whole arena, so a
  write below StackBase IS recorded).  `tools/mame_test/tests/argv_floor.json` +
  `argv_floor_check.py` gate on that.

## Validation (all GREEN)

| Gate | Result |
|---|---|
| stack_measure self-test (signal allowance) | OK |
| fcc fixture goldens `./run.sh` (REGEN + verify) | 379/379; stack_check 572 fns / 0 violations |
| fcc runtime oracle `run_runtime.py` (all fixtures) | 379/379, 0 regressions |
| — sigdbr (exercises B2 crt0 trampoline) | pass (B2 does not false-trap) |
| — stkfloor (Fix A 2-page floor geometry) | 134 (traps) |
| — stkguard | 134 |
| kernel `./build.sh disk` | ok, 45503 B (was 45313; +190 B Fix A loader code) |
| argv_floor spawn-corruption (min_s ≥ StackBase) | GREEN (headroom 337 B) |

(Review closure 2026-07-09: argv_floor_check.py is now wired into the harness
via a new generic `expect.check_script` key in run.py — the corruption verdict
runs on every `run.py argv_floor`, fail-closed (any non-zero checker exit,
including "inconclusive", fails the test).  Previously only the screen check
gated and the checker had to be invoked by hand — the same fail-open shape the
3.3 review fixed in the userland stack_check scan.  RED-proven against a
doctored dump; missing-dump arm also fails closed.)

Only `.expected.bin` goldens drifted (crt0 grew ~18 B from B2 + stkfloor 420 B);
zero `.expected.s`/`.data.s` churn — fcc emit byte-identical (no codegen change).

## Known limitations / fail-closed structure (Fable-reviewed)

- The **E2BIG pre-write gate is UNREACHABLE with current constants** — not merely
  untested.  Max frame `T = 10 + 2·LSARGV_MAX(16)·(128+1+2) = 4202 B`; the gate fires
  only when `T > size − 128`, but the smallest clamped size when ArgsExtraPages asked
  for more is 32 pages = 8192 B, and `4202 < 8064`.  For any request ≤ 32 pages,
  `size ≥ T + 256` by construction.  So NO input (jsh, C harness, anything) trips it
  today — a C-harness RED test is impossible, not deferred.  It is fail-closed
  structural defense that goes live only if `LSARGV_MAX` or the 128-char per-string
  cap grows (noted in the loader comment).  The ACTUAL corruption defense is the page
  accounting, tested end-to-end (argv_floor `min_s ≥ StackBase`).
- **Residual B2 window** (inherent, not new): an UNGUARDED (<128 B) handler frame
  dispatched at S just above StackBase can still write ~122 B below base silently —
  identical to any unguarded leaf at depth, a property of the §6A pad-budget
  convention, not this change.  No action.
- jsh forwards argv correctly (dirname printed its 52-char argv[1]); the deep-frame
  path is reachable by direct posix_spawn C callers (system(), custom spawners).

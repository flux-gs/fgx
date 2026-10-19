# P3-3 #42 — fcc stack pad calibration (DEFAULT_PAD / FCC_STK_FLOOR_MARGIN)

> Phase-3 train, task #42 (GAP 2). Measures the two constants that were
> UNMEASURED guesses (both 128): `DEFAULT_PAD` (toolchain/src/ld/stack_measure.py)
> and `FCC_STK_FLOOR_MARGIN` (include/kernel.s). RELEASE HOLD in force — all
> work local on the P3-3 feature branches. Method reviewed by Fable before
> measuring and again at close.

## What the pad is (geometry)

Since P3-3 fcc locals live on the bank-0 hardware stack (`n,S`). `stack_measure.py`
sums the static C call graph (FRAMESIZE + per-edge CALL_OVERHEAD 5 + ARG_PAD 16)
= `worst`. The linker sizes each binary `pages = ceil((worst + pad)/256)`; the
kernel seeds a per-task guard floor at `StackBase + FCC_STK_FLOOR_MARGIN`
(process.s), and the fcc prologue overflow guard traps (exit 134) a C frame that
would cross it. `pad == margin` = the headroom reserved **below the deepest C
frame** for stack users the static graph cannot see: hand-asm libc pushes, the
syscall/IRQ pre-switch, the IRQ hardware frame, the signal trampoline.

The number to calibrate is therefore the **per-instant excursion**
`e = _fcc_fb - 1 - S` — how far the live S descends below the current C frame
base. Its max is transferable to the worst C depth (an IRQ/signal can land it
there), so `pad >= max_t e(t)`. (Reviewed: min(_fcc_fb) - min(S) is INVALID —
different instants; e(t) is instant-accurate.)

## What consumes the USER task stack (code-read)

- Syscall dispatcher **switches to a per-task kernel stack** after a ~4-6 B
  pre-switch preamble (syscall.s:145-176) — handler depth is OFF the user stack.
- IRQ handler likewise TCS-switches; only the native hw frame (PB/PCH/PCL/P = 4 B)
  + pre-switch lands on the user stack.
- Signal: delivered at syscall exit; the dispatcher pushes [bank,offset-1] on the
  user stack and RTLs to crt0_far `_sig_tramp`, which pushes ~11-14 B
  (PHP+PHX+PHY+PHB+PHY-signum + PHK+PEA return frame) then double-RTLs to the C
  handler. Mechanism ≈ 15 B. **The handler's C subtree is NOT guard-protected**
  and NOT sized: the prologue guard emits STKGUARD=1 only for a >=128 B frame /
  self-recursion / indirect call (parse_stmt.c:4203-4205), so a chain of small
  handler frames is guardless; and stack_measure's `worst = depth(main)` never
  reaches a `signal()`-registered handler (its address is taken, not JSR'd, and
  the dispatch lives in hand-asm `_sig_tramp`), so `indirect==0` — the subtree
  is unsized too. What actually bounds it is the FGX handler CONVENTION
  (docs/developing-userland.md landmine §6A: handlers set a flag ONLY), a
  discipline, not a mechanism. A handler that does real C work is a latent
  pad/overflow hazard — see the follow-up below.
- Pure-libc paths (printf/pf_run, string/mem) run on the user stack; hand-asm
  libc is stack-FRUGAL (uses DP scratch + global buffers, not deep frames).

## The instrument

New fgxdebug tap `stack_excursion` (tools/mame_test/plugins/fgxdebug/init.lua):
one write-tap over the user-stack arena [$3000,$B000); on each write with D in
the per-task DP band ($B1xx..$BFxx — excludes the $B000 kernel DP) it aggregates
per task: `max_e` (+PB:PC snapshot), absolute `min_S`/`max_S`, and the
kernel-seeded guard `floor` (DP $B9) → StackBase = floor-128. MAME write taps
run in the debugger between instructions (no cycle perturbation) and DO catch CPU
pushes (verified: the IRQ hw frame + firmware pushes register). Manifests
tools/mame_test/tests/stkpad_*.json; reducer tools/mame_test/stkpad_analyze.py.

Two honest caveats. (i) The tap attributes by the running D; it is blind to any
push made after a D swap. FGX-authored user code never swaps D (the sole `TCD`
in libc.s is longjmp restoring the SAME task DP), so the only D-swap risk is ROM
interior behavior at the $FF:F885 firmware push — assumed to be the fixed ROM
entry sequence (its 26 B is deterministic across all runs, consistent with that).
(ii) The e/min_S recording now also requires S itself in the arena (added
post-review) so a task-band-D + kernel-S staging write can't poison e with a
stale fb; inert for this run (every recorded extremum already had in-arena S).

## Measured (2026-07-08, disk build of the P3-3 branches, 6 workloads, all pass)

Static C-model (stack_measure): pfwidth worst=4B **pages=0**; ed 286B, sed 192B,
jsh 351B — all **pages=32 (floored: recursion)** → pad-INSENSITIVE. Only small
non-floored binaries (pfwidth-class) are pad-sensitive.

Runtime `max_e` (non-C excursion below the live C frame), worst per workload:

| workload | worst max_e | where (PB:PC) | notes |
|---|---|---|---|
| printf (pfwidth) | 17 B | $6C:17FB (libc) | integer/string formatting |
| **od -e (float)** | **20 B** | $6C:0205 (pf_emit_float/softfloat) | the %e path pfwidth missed — STILL < 26 |
| calc (yacc) | 17 B | $6C:1EB4 (libc) | deep recursive-descent parser; C recursion resets fb |
| ed subst suite | 21 B | $FF:F885 (ROM) + $7D staging | |
| sed | 16 B | $7D:6662 (argv staging) | |
| jsh cmdsubst | 26 B | $FF:F885 (ROM firmware) | **overall worst** |
| sigtest | 16 B | staging | asm handler; mechanism ≈15 B analytic |
| **ntpplay IRQ + ed** | **16 B** | staging | cat ran 613 k tap-hits under live ~50 Hz IRQ; IRQ hw frame + tick handler add ≤ staging |

**WORST runtime non-C excursion across every workload (8 total) = 26 B** (IIgs
ROM firmware $FF:F885, on jsh). The deepest genuine libc path — %e float
formatting via pf_emit_float + softfloat (od -e) — measured 20 B, still under
the firmware figure. Signal mechanism ≈15 B (analytic, ≤ 26). IRQ ≤16 B
(measured under storm). All « the 128 pad.

## Adversarial composition (why 26 B is a safe worst)

Signals deliver only at syscall EXIT (`_Sys_CheckSignal`, a dispatcher-exit
hook), when the interrupted fn is at its normal posture — NOT mid-libc-push (the
syscall already switched to the kernel stack and returned). So the trampoline's
~11-14 B stacks on the fn's frame with no libc excursion live. For a
CONVENTION-compliant handler (flag-set only, §6A), the handler subtree is ~1
tiny frame and the worst push below the interrupted C frame ≈ trampoline +
tiny ≈ 15-20 B. Even the fully-adversarial CONVENTION-compliant stack — an IRQ
hw frame (4 B) landing during the trampoline (14 B) while the minimal handler
touches a float-format libc (20 B) — sums to ~38 B, still < 128 (≈3.4× margin).
The firmware 26 B remains the measured worst; ~38 B is the analytic adversarial
ceiling FOR A COMPLIANT HANDLER. A handler that does unbounded C work escapes
this bound entirely (unsized + unguarded) — that is the second structural gap,
below, not a pad-constant question.

## Decision — keep 128 (both constants), VALIDATED not changed

Worst measured non-C runtime excursion 26 B; 128 = **~5× margin**. Reasons not
to shave (Fable): the pad is the UNGUARDED budget — the prologue guard catches
only C prologues, so a non-C push below StackBase is silent cross-task
corruption, not a loud trap; page granularity means a smaller pad rarely changes
any binary's page count; 128 preserves the tiny-frame+pad-in-one-page property
(small programs stay pages=0, no header churn) which 256 would destroy. Reasons
not to raise: nothing measured needs it. Composite (26 + IRQ + mechanism) ≪ the
~96 raise threshold. **DEFAULT_PAD = FCC_STK_FLOOR_MARGIN = 128 confirmed.** No
binary changes; offset-14 invariant holds trivially (no pad change → no page
change).

## FINDING → follow-up task #45 (flag for the maintainer) — two unaccounted stack consumers

The measurement surfaced two consumers that are INVISIBLE to stack_measure's
`worst = depth(main)` and therefore silently share the pad. No constant fixes
either (both are input/app-dependent); the fix is structural. Promoted to a
numbered follow-up, flagged for the maintainer per the "different structure → ask" rule.

**(A) The kernel-laid argv/envp frame.** `_Loader_StageArgs` (loader.s:884+)
lays the BSD argv/envp frame on the TOP of the child's stack before first run;
the child's S starts BELOW it. Measured T = ~70 B (small tools) up to **263 B
(jsh)** — command-line-dependent. E2BIG (loader.s:1113-1125) fires ONLY if the
frame writes below StackBase — it does NOT reserve `worst+pad` below the frame.

**Silent corruption is CONSTRUCTIBLE TODAY** (Fable, verified against the
numbers): pfwidth is `pages=0` → a 256 B stack, main is `STKGUARD=0` (small
frame, no guard). A ~200 B command line makes T≈200, so the child's initial
S0 ≈ StackBase+56 — already BELOW the guard floor (StackBase+128), and E2BIG
passes (still above StackBase). main then pushes one small frame (~26 B incl.
edge) + a printf excursion (17) + an IRQ frame (16) → S crosses StackBase with
NO trap (the guard sees only C prologues; these are small/non-C pushes). Result:
silent corruption of the neighbouring task's stack top. Fix: `posix_spawn` (which
holds the argv pointers at Task_AllocStack time) computes T and adds
`ceil(T/256)` pages to the header hint — removing the unbounded term from the
pad; then a future re-measure could defensibly tighten 128.

**(B) The signal-handler C subtree.** Registered via `signal()` → unreachable
from main → unsized by stack_measure; small handler frames are STKGUARD=0 →
unguarded (see the Signal bullet above). Today only the §6A "flag-set only"
CONVENTION keeps it safe. stack_measure could add a maxfn-style allowance when a
TU references `signal()`/`sigaction()` (the handler is a statically known
symbol), and/or fcc could force STKGUARD=1 on any function whose address is
passed to `signal()`. Same class as (A): a sizing gap, not a pad-constant one.

## System math (step 4) — no change, because the pad is unchanged

- **offset-14 sweep**: DEFAULT_PAD value unchanged (128) → no binary's
  `pages = ceil((worst+pad)/256)` changes → no FGX2 header offset-14 byte
  changes. Confirmed: pfwidth still `pages=0`; `./build.sh disk` produced a
  **byte-identical kernel (45313 B)** and rebuilt every userland tool with the
  in-build stack_check gate green.
- **arena budget**: unchanged from the #43-validated state (pad is the only
  lever and it didn't move). FGX_STK_ARENA = 112 pages (28 KB). Floored
  recursive tools (ed/sed/jsh) take 32 pages (8 KB) each; a realistic set
  (jsh 32 + a 2-stage pipe) fits, a 3-stage pipe of floored tools can exhaust
  it — the pre-existing #43 boundary, not moved here. Failure mode is a clean
  `Task_AllocStack` → ENOMEM spawn-fail (task.s "No N-page contiguous run" →
  `LDA #ENOMEM`), not a hang. Empirically confirmed: `stkpad_irqc` ran
  `cat | ed` (2-stage pipe) with ntpplay resident under a live IRQ — clean, no
  ENOMEM, no hang.

## Gates

- toolchain `stack_measure` module self-check: **OK**; `stack_check --self-test`:
  **OK** (7/7 incl. the 3 forbidden-token reds).
- FGX `./build.sh disk`: **green**, kernel **45313 B (byte-identical)**, in-build
  userland stack_check clean, disk verified.
- MAME: **sigtest OK** (via stkpad_sig, on the real image); all 8 stkpad_*
  workloads pass.
- fcc oracle + M1 stkguard/stkfloor/sigdbr goldens: **not re-run — no fcc /
  libc / codegen / constant-VALUE change** (comment-only in stack_measure.py;
  the floor seed those fixtures gate is bit-for-bit identical; kernel byte-inert).

## Pre-existing residue confirmed (not #42; prompt WATCH item)

ed `commands` and jsh `_jsh_run_seq` are MUTUAL recursion cycles with STKGUARD=0
(per-TU fcc cannot see the cycle) → unbounded input overruns the 32-page cap
UNGUARDED. Orthogonal to the pad; the fgx_ld mutual-recursion warning already
flags them. Deep-recursion input hardening is a separate item.

## Stale-doc sweep (both repos)

- toolchain/src/ld/stack_measure.py "NOT yet empirically calibrated … named
  follow-up" → updated: calibrated 2026-07-08, worst 26 B, 128 = 5× margin.
- include/kernel.s:193-195 "(pad-calibration item, 3.2b step 6)" → updated: done.
- docs/history/plans/2026-07-07-fgx-p33-soft-stack-delete.md:220 ("measure via
  the capture_writes stack tap and pad ≥ that; fcc's old +128 was a guess") →
  this doc closes it. (ROADMAP.md carries no pad line — checked.)

Coverage note: the initial workload set (pfwidth/ed/sed/jsh) was int/string/IO
only; a dedicated `od -e` run was added to exercise the ONE hand-asm libc
subsystem with real internal call depth — float formatting (`pf_emit_float` +
softfloat `_fcc_ffloor/_fcc_ftol`) — measuring 20 B, under the 26 B worst.

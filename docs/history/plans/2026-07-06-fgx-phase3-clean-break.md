# Phase 3 — the clean break: implementation train

*2026-07-06, written at Phase-2 completion.  Sources:
`docs/history/plans/architecture-redesign.md` Part III/IV + the audit archive
(`libc-bank-independence.md`, `softstack-deletion.md`,
`syscall-abi-widening.md`).  Every increment lands gate-green under the
release hold; the flag day itself is one release train (toolchain first,
FGX re-pin, world rebuild).*

## Prerequisite status (checked 2026-07-06)

- **Phase 2 (multipass front-end): COMPLETE** — typed per-function trees,
  pure walkers, stable symbol handles (see
  `2026-07-06-fcc-phase2-frontend.md`).  T1's "one funnel per operation"
  precondition is met: every lowering decision already routes through one
  walker arm.
- **Phase 1 (T5-A shared libc): NOT EXECUTED** — the migration path
  ordered it before the break and it is pure win (~45KB/elvis-class
  binary).  Prerequisite verified MET (bank-independence probe).  It is
  increment P3-0 below.
- **Phase-0 measurements (T4 gate): NOT DONE** — the soft-stack
  high-water, frame sums, and size-tax numbers that size T4.  Increment
  P3-1.

## The train

- **P3-0 — shared libc segment (T5-A backfill).  ★DONE 2026-07-06**
  (feat/shared-libc both repos, merged under the hold).  Gates: goldens
  364/364 (0 .expected.s churn — FGX1 emission byte-identical; all 364
  .expected.bin regenerated for the deliberate `_an_nl` CR→LF tree-sync
  byte), oracle 344/344, sweep 35/35 exit 42 on the pile-once link
  (first run caught my wrong `_libc_epoch` offset shift via c32/c33 —
  its callers push a local arg frame, offsets are flavor-independent),
  MAME FGX2 battery 19/19 real tests (ed×5, sed×7, stattest,
  msgtest_fmt, fswbig, tgstest, tctest_fgx2, jsh×2; two stale untracked
  probe JSONs excluded: heaptest binary never in build, msgtest.json
  expects the pre-fmt output), near-flavor cat.bin byte-identical,
  **elvis 329,769 B vs 357,113 B = −27.3 KB** and links clean through
  fgx_ld.  Original spec follows; refinement addendum below governs.
  Mechanical, itemized
  by the probe: setjmp PHK→JSL-frame PB (+ frame offsets, ~10 lines);
  RTS→RTL on the 66 public entries; +1 `n,S` shift at 191
  fcc_libc_shims.s sites (+1 in libc.s); 11 dual-use `_fcc_*` symbols'
  internal JSR callers become same-bank JSL so one RTL exit serves both;
  fcc emits FGX2_FARCALL for libc/runtime calls (mechanism exists);
  crt0_far's near-JSR to _crt0_setup_argv resolved (JSL or keep args.s
  beside crt0); link generators (gen_elvis_link.py, gen_sweep_link.py,
  build_userbin_fgx2_c) emit the pile ONCE.  Gate: sweep 35/35 + oracle +
  elvis link size (expect ~45KB smaller) + ed/sed suites.
  **De-risk audit DONE (2026-07-06): zero hand-asm/kernel/module callers
  JSR into the pile** — every caller is fcc-generated code rebuilt in
  lockstep, so the RTS→RTL + JSL-emission pair is atomic within one
  toolchain build; no out-of-band ABI exposure.  Also unify the
  two libc trees (toolchain = source of truth) — the copy-divergence is
  1 comment + tc_ti/tc_te.
  **Design refinement at execution (2026-07-06), from live probes:**
  (1) **fcc_runtime.s stays per-bank** — it is 3,545 B of the 11,303 B
  pile; sharing it would convert 31 hot register-ABI helpers, ~67 raw
  `JSR _fcc_*` emission sites in fcc, and the ir/peephole call-clean
  classifiers, all of which P3-2/P3-3 redesign anyway (double work, hot
  path +2cy/call).  The shared far segment is **libc.s + shims + args**
  (7,758 B); elvis saves ~23 KB now, the runtime share lands with P3-2.
  This also zeroes the "11 dual-use JSL" item (all dual-use symbols are
  `_fcc_*`) — **no libc/shim public is called from inside the pile**.
  (2) **Flavoring**: per-wrapper `LIBC_FAR EQU 0|1`; offsets become
  `n+LIBC_FAR,S` (no conditionals); public exits use `DO LIBC_FAR /
  RTL / ELSE / RTS / FIN` (merlin32-verified incl. inside MAC).  FGX1
  keeps the near flavor — the oracle's 344 fixtures are FGX1 ('FGX1'
  magic, no libc in `_wrap.s`), and remaining FGX1 C tools (~30) stay
  untouched semantically (+1 EQU line per wrapper).
  (3) **All FGX2 links flip to far libc** (single-bank included): fcc
  emits FGX2_FARCALL for lb-resolved/printf-family/setjmp-longjmp calls
  when `--data-segment` or `--far-calls`; unknown externs (per-tool
  `*_stubs.s`, JSR/RTS `3,S` ABI) stay near.  This puts the ed/sed
  suites + every FGX2 mame test on the far pile — the real runtime
  gate.  Goldens compile FGX1-mode only (verified: run.sh bare `fcc`)
  → stay byte-identical.
  (4) **Exports without macro plumbing**: merlin32 errors on undefined
  macros even in a false DO arm, and FGX1 wrappers don't PUT macros.s —
  so libc.s/shims define their own empty `LIBC_EXPORT` MAC (0 bytes,
  harmless everywhere) invoked after each public label; fgx_ld learns
  it beside FGX2_EXPORT (~2 lines).
  (5) **fas**: NOT a gate — fas has no MAC support and already dies on
  fcc_libc_shims.s:42 (`SYSCALL_PTRARG MAC`) today, so libc-PUTting
  fixtures never fas-assemble; DO/ELSE/FIN + MAC land together with the
  existing fas-regressions backlog.
  (6) crt0_far's near-JSR to `_crt0_setup_argv` needs no change: args.s
  rides in seg0 beside crt0 in every layout.
- **P3-1 — the T4 measurements.  ★DONE 2026-07-06** — full numbers in
  docs/history/audits/2026-07-06-p31-t4-measurements.md.  Headlines:
  shipped userland soft-stack use ≤100 B measured (ed 64 B over the whole
  substitute suite, jsh 98 B; new fgxdebug `watch_min` aggregator +
  tools/stack_measure.py static sums), elvis-class ≈5 KB static (2,144 B
  direct graph + add()=4,128 B via key dispatch — boxing candidates =
  its five >1 KB frames), soft-stack size tax = +7.6…+14.4% instructions
  (ed/sed/grep, hard-vs-soft @ e0411f0).  T4's hybrid (HW stack + boxing,
  TASK_STACK_MAX_PAGES 16→32) is confirmed with data.  Original spec:
  (a) per-binary call-graph frame sums — extend fcc's g_max_framesize
  into a per-function dump + a cross-TU summing script over the shipped
  userland; (b) soft-stack high-water via fgxdebug capture_writes on
  `_fcc_ssp` (DP $BC) — workloads: ed + sed suites, jsh interactive
  script, tctest; elvis is OFF THE TABLE as a runtime workload, so the
  5–6KB design estimate stands for elvis-class unless re-tabled —
  document that gap; (c) soft-stack size tax — rebuild 2–3 big TUs with
  pre-b31e84f fcc (resurrected read-only from git) and diff sizes.
- **P3-2 — T1: the pointer model** (the core, Phase-2-sized).
  **Plan doc: `2026-07-07-fcc-p32-pointer-model.md`** (audit, design,
  increment ladder 2.0-2.7 — execute from there).
  tword grows the width/address-space property;
  pointer rvalues become self-contained offset+bank pairs in
  per-expression DP far-pointer registers (generalizing the DP-IMG
  promoted pair); `_fcc_ptr/_fcc_ptr+2` retired as a shared carrier;
  PHK/PHB/#0/stored-bank decisions collapse to one place each (the
  walker arms are already the funnels); `--far-calls`/`--data-segment`
  retired — multibank becomes the only mode, single-bank a degenerate
  case.  Validation reality: goldens churn 100% BY DESIGN (new codegen)
  — the correctness net is the oracle + sweep + FCC_AST_CHECK + the
  old-vs-new differential in BEHAVIOR (exit codes), not bytes; goldens
  regenerate per milestone.  Cost levers: constant-offset-into-Y fold,
  staging reuse, DP-IMG promotion; P3-1(c) quantifies the base tax.
- **P3-3 — T4: soft stack deleted** (hybrid, data-informed by P3-1).
  Locals to bank-0 hardware stack (`n,S`; `&local` = bank 0 by
  construction); compiler-owned heap-boxing for >~1KB aggregates
  (prologue mallocs, epilogue frees); >255-offset far fallback returns
  (_fcc_fp, G53 precedent); call-graph-sum stack sizing + the FGX2/FGX3
  manifest stack field FGX2 never had; TASK_STACK_MAX_PAGES 16→32;
  prologue TSC/CMP guard on big frames.  The fourth bank class and the
  caller-buffer-bank rule (for locals) die here.
- **P3-4 — T6: kernel ABI v2.**  Widen the 9–11 multi-pointer calls
  (STAT/FSTAT, LISTDIR, EXECVE, SPAWN family argv/file-actions, socket
  argblks + bank fields, WAIT/WAITPID status far-ptr subsuming
  TCB_DataBank); keep _Sys_CallerBank for the 22 single-pointer calls;
  wire structs get defined shapes (fcc's layout is already
  PDP-11-correct post-B-8).  errno is ALREADY real (quick-wins batch).
- **P3-5 — T3: FGX3 format.**  Typed relocations by construction from
  the type (BANK16/IMM24 analogs), ABI/mode stamp (mixing = link error,
  extends the D1 gate), stack-size field, per-task reloc tables (text
  sharing), linker-synthesized deduplicated JML trampolines replacing
  the 3-layer fn-ptr dispatch.  Loader dispatches on magic beside
  FGX1/FGX2 during bring-up.  OPEN (decide during design): exact reloc
  record shapes; text-sharing indirection cost at NPROC=8.
- **P3-6 — flag day.**  One release train: toolchain (MULTIBANK_VERIFIED,
  sweep now 35 constructs), FGX re-pin, world rebuilt as FGX3; FGX1
  retires (legacy tools recompile as single-segment FGX3).

## Sequencing notes

- P3-0 and P3-1 are independent of each other and of the hold; both are
  shippable stand-alone.
- P3-2 (T1) before P3-3 (T4): heap-boxing wants the far-pointer node
  lowering T1 builds.  P3-4/P3-5 ride the same recompile world; their
  designs can proceed in parallel with P3-2.
- The FCC_OLD_EXPR fallback grammar retires after P3-2 stabilizes (it
  cannot express the new pointer model).

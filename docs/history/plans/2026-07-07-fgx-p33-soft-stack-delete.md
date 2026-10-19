# P3-3 — T4: delete the software stack (locals → bank-0 hardware stack)

> Phase-3 "clean break" train, increment **P3-3**. Parent plan:
> `docs/history/plans/2026-07-06-fgx-phase3-clean-break.md` (P3-3 paragraph).
> Sizing data: `docs/history/audits/2026-07-06-p31-t4-measurements.md`.
> Design reviewed by the Fable advisor 2026-07-07 (FP-repoint staging +
> five missed hazards + two YAGNI cuts adopted below).
> Branches: toolchain `feat/p33-soft-stack-delete`, FGX
> `feat/p33-soft-stack-delete-fgx`. **RELEASE HOLD in force** — local
> branch/tag/merge only; no push / no release.sh until the maintainer green-lights.

## Goal

Delete the per-task **software stack**. C locals move to the **bank-0
hardware stack** addressed `n,S`; `&local` becomes bank 0 by
construction; the fourth bank class and the libc-shim
"caller-buffer-bank" rule (for locals) die. Frame sizing moves into a
binary **manifest stack field** the loader honours. This is the T4 leg
of the Phase-3 architecture redesign.

## Current state (verified in src/cc, 2026-07-07 @ toolchain 1c8d12a3)

- **Locals** live on a per-task malloc'd soft stack: addressed
  `[_fcc_ssp],Y`, `Y = 2*slot_first + off`, **no** stack-pointer bias.
  `_fcc_ssp` is a fixed DP far pointer ($BC). Prologue
  `_fcc_ssp -= FRAMESIZE`; epilogue `+= FRAMESIZE`
  (`emit_prologue_unconditional` / `emit_epilogue_return`, emit.c
  1433/1445). `FRAMESIZE EQU 2*g_total_slots` is emitted at function
  **end** (parse_stmt.c:4191); body references are forward-refs Merlin
  resolves in pass 1.
- **Params** already live on the hardware stack, `n,S`. `local_offset()`
  (main.c) returns `retn+1+param_byte_offset+g_s_delta` for params —
  **no FRAMESIZE term today**, because the soft stack keeps no local
  frame between S and the return address.
- **Crux:** `local_offset()` for a LOCAL *already returns the
  hardware-stack form* `2*slot_first + 1 + g_s_delta`, and
  `slot_addr_str()` already formats a plain `n,S` operand. The offset
  machinery is half-prepped; only the emit arms still use `[_fcc_ssp],Y`.
- **`_fcc_fp` far fallback** (>255 `n,S` offset) already exists for
  params: `DO off/256` Merlin gate → bank-0 long pointer
  `TSC/CLC/ADC/STA _fcc_fp` → `[_fcc_fp]` (emit.c 147/172, G53).
- **Pointers** are DP FPR (offset+bank) pairs post-P3-2. `&local`
  currently yields the soft-stack bank; after P3-3 it yields bank 0.
- **Kernel** `TASK_STACK_MAX_PAGES` = 16 (4 KB hw stack/task). Task DP at
  `$B000 + pid<<8`; `_fcc_ssp` at DP $BC. Measured: shipped userland
  uses ≤100 B of stack (ed 64 B, jsh 98 B); only elvis (OFF the table as
  a runtime workload) has >1 KB frames (five: 1002–4128 B).

## Design decision — FP-repoint staging (NOT an atomic flip)

The naive plan (flip prologue + every emit arm in one commit) is an
un-bisectable big-bang the exit-code oracle would wave a `g_s_delta`
off-by-2 straight through. Instead, **repoint `_fcc_ssp` at the hardware
stack first**, then convert emit arms family-by-family:

- Prologue (staging): `PEI _fcc_ssp` (save caller frame ptr — 16-bit
  offset; bank is 0 for all frames after the first) → `TSC/SEC/SBC
  #FRAMESIZE/TCS` → `_fcc_ssp = S+1`, `STZ _fcc_ssp+2` (bank 0).
- Epilogue (staging): stage return value in Y (TSC clobbers A) →
  `TSC/CLC/ADC #FRAMESIZE/TCS` → `PLA/STA _fcc_ssp` (restore caller
  frame) → `TYA/RTL`. Return value staged **before** the dealloc and
  never re-read from the frame after TCS (IRQ-above-S discipline).

Why this is strictly safer:

1. **Every existing `[_fcc_ssp],Y` arm keeps working unmodified** — it
   now addresses hardware-stack memory. Storage moves in one small
   prologue/epilogue-only step; the dozens of emit arms don't change.
2. **Both forms coexist against the same bytes.** `[_fcc_ssp],Y` is
   frame-pointer-relative (immune to mid-expression pushes); `n,S +
   g_s_delta` is S-relative (tracks pushes). Both are correct
   simultaneously, so arms convert **one family at a time**, each behind
   its own oracle + static-checker gate.
3. **`&local` = bank 0 falls out for free** the moment `_fcc_ssp` points
   at bank 0. The libc-shim caller-buffer-bank rule for locals dies the
   same step — it was never actually separable from the storage move.

The FP save/restore scaffolding (~10 bytes/fn) is deleted at 3.3.

## Hazards the naive plan missed (all from the Fable review)

- **Param offsets shift by `+FRAMESIZE+2`.** Once the prologue moves S,
  every param sits above the frame: `local_offset()` param arm gains
  `+FRAMESIZE + 2` (the +2 = the saved-FP PEI word). One centralized
  edit, but it touches every param access in the world and makes the
  `DO off/256` far-gate fire for params in any function with a >~200 B
  frame. **This means params re-acquire a symbolic-FRAMESIZE `n,S`
  operand and a forward-ref inside `DO (num+FRAMESIZE)/256`.**
  ✔ **RESOLVED (3.0 empirical probe):** merlin32 builds its full label
  table before the code passes, so a forward-referenced EQU inside `DO
  OFF+FRM/256` resolves and selects the correct branch (probed: 310 →
  far `A9 AA`, 50 → near `A9 BB`). **No numeric-FRAMESIZE refactor
  needed** — keep the symbolic-EQU mechanism.
- **setjmp/longjmp must capture S** (and, during the staging window,
  both S and `_fcc_ssp`). Today `jmp_buf` captures `_fcc_ssp`; a stale
  restore is a live miscompile, not cleanup. Update the builtin in 3.1a;
  red-first fixture in 3.0.
- **IRQ discipline (new hazard class).** Locals now share the stack IRQs
  push to. Invariant: the frame is strictly above S at every
  instruction, and nothing reads frame memory after the epilogue TCS
  raises S. Audit epilogue return-value staging + any "dealloc then
  fix-up" arm. Add an IRQ-storm (timer-tick-heavy) MAME battery run.
- **Peephole push-reorder audit.** Any peephole rule that deletes,
  introduces, or reorders a push across an `n,S` operand silently breaks
  the displacement (runtime stack imbalance — invisible to compile-time
  offsets, so distinct from the g_s_delta class). Load-bearing now for
  every local access; extend the existing "PEI⇒audit peephole reads_loc"
  pass.
- **`_fcc_fp` is a single DP temp.** Once far-fallback gets hot (medium
  frames + params past 255), audit for two far operands in one
  expression (`bigframe_dst[i] = bigframe_src[i]`): build-then-second-far
  before consume = silent clobber, single-small-frame-invisible.

## g_s_delta hunting — the static checker is the real net

Locals are accessed far more than params, so any latent `g_s_delta` bias
bug that params never tripped surfaces here, and a bias bug reads a
*neighbouring slot* that frequently still exits 0. Three layers:

1. **Static `n,S`-vs-depth checker** (`tools/stack_check.py`, new):
   symbolically track stack depth through every PHA/PHX/PHY/PEI/PEA/PHB/
   PHD/PLx/JSR/JSL per basic block over the generated asm and validate
   every `n,S` operand against tracked depth + the function's slot map.
   Mechanical, checks *every function in the world rebuild*, catches the
   exact invariant the oracle passes. This is the primary net. **Built
   at 3.1a, not 3.0** — it has nothing to validate until locals first
   emit `n,S` (today's locals are `[_fcc_ssp],Y`, no HW-stack slot map);
   a linter run against soft-stack output would only re-check params.
   It becomes the per-increment gate from 3.1a onward.
2. **fcc source audit:** every push-emit site in **both** call emitters
   (parse_expr + parse_stmt — dual-emitter trap) and the peephole bumps
   `g_s_delta`.
3. **Runtime tap:** `capture_writes` on the stack region catches writes
   below S or into a dead frame at MAME level.

## Increment ladder (gate cadence per step: goldens regen + MAME oracle + multibank sweep + AST_CHECK + world rebuild + extended battery)

- **3.0 — Behaviour-baseline fixtures + Merlin `DO` probe. ✔ DONE.**
  Six new `tests/M35/` fixtures, all PASS under the current soft stack
  (MAME oracle 6/6) = the behaviour baseline the differential preserves:
  `p33_frame_deep` (>255 slot far-gate), `p33_sdelta` (g_s_delta stress:
  `f(g(loc),loc)` nested args + interleaved pushes), `p33_addr_bank`
  (`&local`→callee deref, bank0), `p33_recurse` (per-frame re-entrancy),
  `p33_localagg` (local struct via &local + 2D local array),
  `p33_fcc_fp_dbl` (two far scalars in one expr — `_fcc_fp` collision).
  setjmp/longjmp across frames is already anchored by `M29/setjmp_jump`.
  All cross-checked on clang (return 42). Merlin `DO forwardEQU/256`
  probe ✔ (resolves — no numeric refactor). No codegen change.
- **3.1a — FP-repoint (storage move).** Prologue/epilogue → HW-stack
  frame with FP save/restore (above); `local_offset()` param arm gains
  `+FRAMESIZE+2`; setjmp/longjmp capture S. All `[_fcc_ssp],Y` arms now
  hit the HW stack; `&local`==bank0 falls out; caller-buffer-bank rule
  for locals dies. **Build `tools/stack_check.py` here** (first n,S
  locals to validate) and add it to the gate. Oracle + checker gated.
- **3.1b…n — Convert emit arms `[_fcc_ssp],Y → n,S + _fcc_fp`,
  family-by-family:** (b) scalar load/store (emit_slot_lda16/sta16,
  emit_field_lda/sta); (c) struct/array field + element access;
  (d) the carrier survivors (deref-postinc/deref-fast IR family, member
  incdec, ptr-local preinc, printf arg staging). Each step oracle +
  static-checker gated.
  **✔ DONE 2026-07-08 — with a delivered-scope amendment (review-ratified):**
  family (d) as EXECUTED = `emit_binop_mem_local` (the last direct
  `[_fcc_ssp],Y` VALUE arm).  The carrier survivors listed above turned out
  to reduce to family-(b) slot ops (their pointer-variable load/store) plus
  derefs through a runtime-computed address — which structurally CANNOT be a
  constant `n,S` displacement.  Their `_fcc_ssp`-based address builds and
  `_fcc_ssp+2` bank reads are therefore 3.3's rebase work, not a 3.1b
  conversion (see the 3.3 prerequisite below).  Review closure also wired
  stack_check into `make test` (incl. REGEN), performed the source-level
  push-site audit (verdict: clean), unified the bare param 4-byte
  field-store arms, annotated the remaining slot sites, restored the
  promoted-scalar fixture, and runtime-RED-proved the far fixtures.
- **3.2 — FGX2 stack-size field. ⚠ REORDERED: this is a PREREQUISITE for
  the flip, not a follow-on.** Moving frames onto the HW stack means any
  frame > ~256 B overruns the task's default 1-page HW stack and hangs.
  The existing oracle ALREADY has large-frame fixtures (g53_bigframe,
  g53_param, ptr_bigframe, ss_bigbuf — >255 B frames testing the
  far-fallback); they hang under the bare 3.1a flip, so the full oracle
  cannot gate the flip until this lands. **Do 3.2 immediately after 3.1a,
  before the full-oracle gate; 3.1b conversion follows.**
  Machinery status (half exists):
  - ✔ The kernel loader ALREADY reads a `stack_pages_hint` at the shared
    16-byte header **offset 14** (`FGX1_OFF_STACK`) and passes it to
    `Task_AllocStack` (carves N bank-0 pages from `FGX_STK_ARENA`, clamps
    [1,16]=`TASK_STACK_MAX_PAGES`). This path runs for FGX2 too
    (`process.s:252`).
  - ✘ fcc still COMPUTES `sp = ceil((g_max_framesize+128)/256)` but its
    EMISSION was **retired at the FGX2 mode-collapse** (`main.c:420` —
    frames lived on the soft stack then). So FGX2 offset-14 = 0 → loader
    defaults to 1 page → overrun.
  - ✘ `fgx_ld.py` builds the FGX2 header with no stack field.
  Work: fcc emits its stack-pages value → `fgx_ld.py` writes it at FGX2
  header offset 14 → loader honours it (done). **Sizing must be the
  call-graph frame SUM along the deepest path, NOT max-single-frame**
  (`tools/stack_measure.py` already computes this; fcc is single-TU so
  the sum is link-time). Recursion / fn-ptr calls → generous fixed size +
  **mandatory** prologue TSC/CMP overflow guard (never a fake-precise
  number). The loader defaults to **1 page** when the offset-14 hint is 0
  (small programs); `TASK_STACK_MAX_PAGES` (=16) is the **clamp/ceiling**, NOT
  a default (F4). Size up per-binary via offset 14. ⚠ **F1/F3 (review):** the
  deepest-path sum must include per-call overhead (5 B + args/level, not just
  FRAMESIZE — done in `stack_measure.py`), and a single frame >4 KB (e.g.
  `ss_bigbuf`, 4098 B → 17 pages) **cannot** fit the 16-page ceiling — such a
  fixture forces the `TASK_STACK_MAX_PAGES` 16→32 call (or heap-boxing), a
  scope decision for the maintainer. Gate on **bank-0 budget**: NPROC × pages +
  `FGX_STK_ARENA` + DP ($B000+pid<<8) + kernel + vectors must fit bank 0.

  **3.2 build (Fable-reviewed 2026-07-07):**
  - **Sizing owner = the LINKER.** Wire `fgx_ld.py` to call
    `stack_measure.py` over the assembled segs → deepest-path byte SUM →
    `ceil(/256)` + headroom pad → clamp [1,16] → write header offset 14.
    New code = a call + a byte-write; the graph analysis already exists.
    **Leave fcc's retired single-TU `sp` dead** — it is structurally the
    wrong metric (a single-TU max-frame can't be right for a cross-TU
    chain).
  - **Headroom pad = the calibration knob — MEASURE it.** The C call
    graph does NOT see hand-asm libc/syscall pushes or IRQ nesting (all
    on the same bank-0 stack), so the static sum is a FLOOR. Measure
    worst-case non-C depth (deepest syscall frame + max IRQ nesting) via
    the `capture_writes` stack tap and pad ≥ that. fcc's old `+128` was a
    soft-stack-era guess; verify one page covers syscall-under-IRQ.
  - **Overflow guard:** loader/crt0 caches `TCB_StackBase` into a fixed
    DP slot (`_fcc_stkfloor`, sibling to `_fcc_ssp`); prologue
    `TSC/SEC/SBC #FRAMESIZE/CMP _fcc_stkfloor/BCC __stk_overflow` BEFORE
    the TCS. Emit ONLY on recursive / indirect-reachable / big-frame
    (≥½ page) functions — not universal. It checks the real runtime
    floor, so needn't agree with the offset-14 number.
  - **Recursion / fn-ptr TU → size to max (16) + mandatory guard**, never
    a fake-precise offset-14.
  - **Bank-0 budget check (before trusting size-up):**
    `sizeof(FGX_STK_ARENA) ≥ NPROC × 16 pages`? If NOT, the bet that N
    big-stack tasks don't run concurrently is valid ONLY IF
    `Task_AllocStack` FAILS the spawn cleanly on arena exhaustion (not
    hang, not silent clamp-to-1-then-overrun) AND the spawner surfaces
    the error — verify that path.
- **3.3 — Cleanup.** Delete the `_fcc_ssp` DP band ($BC–$BE), the crt0
  soft-stack malloc/seed, the FP save/restore scaffolding, the fourth
  bank class, the caller-buffer-bank-for-locals rule/docs, and the dead
  soft-stack emit arms.
  **⚠ HARD PREREQUISITE DECISION (3.1b review, 2026-07-08) — settle before
  starting 3.3.** The surviving `_fcc_ssp` users (the `&local` carrier, the
  soft-array element paths, the `_fcc_ssp+2` bank reads) are today
  FRAME-POINTER-relative, i.e. **g_s_delta-IMMUNE**, and they are INVISIBLE
  to stack_check (they deref `[_fcc_ptr]`/FPRs — no `n,S` operand to
  validate).  Naively rebasing them at point-of-use to `TSC + offset +
  g_s_delta` reintroduces the exact delta-bias hazard class 3.1b was
  defended against, in a form with NO static net.  Choose one:
  (a) **keep a frame-base DP slot, TSC-seeded in the prologue** (a frame
  pointer without the soft-stack malloc — carrier arms stay delta-immune,
  one DP word survives; the $BC-$BE band still shrinks); or
  (b) rebase to TSC at point-of-use AND extend the `fccstk` annotation +
  checker to validate TSC-based address builds (annotate the `ADC #off`
  with d=/b= and teach the tracker to check it).
  (a) is the low-risk default; (b) buys ~1 DP word + per-use TSC cost
  parity at real checker-extension cost.
  **✔ DONE 2026-07-08 (option (a); the maintainer ruled "full increment now").**  KEY
  FINDING: option (a) was ALREADY implemented at 3.1a — `_fcc_ssp` was already
  the TSC-seeded, bank-0-invariant frame base (prologue PEI/TSC/TCS/STA/INC,
  epilogue PLA-restore, longjmp restore).  So 3.3 reduced to pure cleanup:
  (1) prologue drops `STZ _fcc_ssp+2`; (2) the 9 carrier bank reads fold to a
  constant 0 via a byte-inert operand swap `LDA _fcc_ssp+2 -> LDA #0` (keeping
  the `STA X+2` so the peephole's dead-store elimination is undisturbed — a
  `STZ X+2` fold defeated it, reverted); (3) crt0.s/crt0_far.s/crt0_c.s
  vestigial 16 KB malloc/seed deleted; (4) $BE + $BF freed; (5) `_fcc_ssp` ->
  `_fcc_fb` (proven byte-inert: same EQU $BC, golden .bin byte-identical); (6)
  fail-closed forbidden-token net in stack_check (`_fcc_ssp` / `_fcc_fb+<n>` /
  `[_fcc_fb]`) wired into `make test`; (7) caller-buffer-bank-for-locals
  rationale + soft-stack comments/error-strings retired.  Commits: toolchain
  `a41d8057` (functional) + `c0780bf2` (rename+net); FGX `a26efcf8` (crt0_c +
  libc sync + first HW-stack rebuild of shipping tools).  Gates: goldens 379/379
  byte-exact + stack_check 381/572/0; oracle --use-fcc 379/379 (0 regressions);
  multibank =MBEND 042; offset-14 invariant; code −9099 B (−0.161%) + 16 KB/task
  heap reclaimed; FGX disk OK (kernel 45313 B) + userland stack_check 387 fns/0
  + MAME sigtest/ntpplay_irqtick/sleeptest 3/3.  RESUME-2026-07-08-p33-3.3-DONE.

## Cut as YAGNI (Fable review)

- **Heap-boxing for >1 KB aggregates — DEFERRED, not built.** Shipped
  userland ≤100 B; the only >1 KB frames are in elvis, which is off the
  table as a runtime workload. Building prologue-malloc/epilogue-free
  would introduce a *new leak class* (longjmp/signal bypass the free) to
  serve zero live programs. The manifest per-binary stack size covers
  the real need. **Revisit at elvis revival**, gated on the bank-0
  budget math; if it returns, the minimal mitigation is (a) a
  compile-time error when a heap-boxed frame coexists with setjmp in the
  same function (fails closed, à la jmp_buf-must-be-global) and (b)
  task-teardown frees the task arena (bounds leaks to task lifetime).
- **Blanket TASK_STACK_MAX_PAGES 16→32 — NOT done.** Doubling every
  task's bank-0 footprint to serve non-existent programs. Manifest-driven
  sizing with default 16 is the mechanism.

## Sequencing / notes

- P3-2 (pointer model) is the prerequisite and is DONE — `&local` uses
  the FPR pointer carrier, and pointer-return homing is FPR0.
- The exit-code oracle is necessary but NOT sufficient here; the static
  `n,S`-vs-depth checker is the load-bearing net. Built at **3.1a/3.1b** (F4),
  NOT 3.0 — it has no `n,S` local emission to validate until then (the
  increment ladder above is authoritative; this line was stale).
- Never rebuild fcc / run tests while a MAME battery or run_runtime.py is
  mid-run. `make` only from the toolchain ROOT.

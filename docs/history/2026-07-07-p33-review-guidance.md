# P3-3 review (Plan + 3.0 + 3.1a) — findings & guidance for the implementing session

Reviewed 2026-07-07 (Fable), covering toolchain `6355908c` (3.0) + `a5ea8c9d`
(3.1a), FGX `d8d56f37`/`e767cdf6`/`6c22832d`/`8e3b77eb`, the plan doc
(`plans/2026-07-07-fgx-p33-soft-stack-delete.md`), and the RESUME. Verified
against source, emitted asm, the peephole, and a full MAME-oracle run the
review itself performed.

## What was verified GOOD (no action)

- **FP-repoint core is correct.** Frame math checked against emitted asm
  (`M35/p33_recurse.expected.s`): locals `[FB..FB+FRAMESIZE-1]`, saved-FP word,
  3-byte JSL return, params at `off+2+FRAMESIZE,S` — `6+fib_FRAMESIZE,S` = 10,S
  with FRAMESIZE=4 is exactly right. Prologue/epilogue IRQ-window analysis
  holds (IRQ pushes below S never touch live frame bytes or the saved FP).
- **Peephole safety is real, not asserted.** `PEI` is in `reads_mem`
  (peephole.c:452 — learned from the jsh FPR-arg bug), `pat_dead_store`
  barriers on labels/control/`FGX2_FARCALL`/PHP/MVN and scans DO/ELSE/FIN
  soundly; `[_fcc_ssp],Y` reads protect `_fcc_ssp+1/+2` via the suffix rule.
  The prologue `STA/INC` memory-RMW choice is genuinely peephole-stable.
- **Params >255 are covered** by the pre-existing `DO %s/256` far-gate through
  `_fcc_fp` (emit_slot_lda16/sta16); symbolic FRAMESIZE resolves inside `DO`
  (probe was decisive, goldens' .bin prove assembly).
- **setjmp/longjmp `_fcc_ssp` save/restore** is a real latent-bug fix and is
  backward-compatible with old-model binaries (offset word restore is correct
  under the soft stack too; bank byte untouched). Trees byte-identical.
- **Fixture quality** is high: exit-code-distinctive arithmetic (sdelta),
  cross-TU deref through the far pointer (addr_bank), recursion, &-taken
  locals across longjmp. clang cross-checks are stated per-fixture.
- `sp` emission confirmed fully retired and all fcc output FGX2-shaped —
  there is no separate FGX1 stack-field exposure.

## Findings (ranked)

### F1 — HIGH (will bite at 3.2): `stack_measure.py` misses per-call overhead

The plan's 3.2 build says the deepest-path frame SUM is needed and
"`tools/stack_measure.py` already computes this." **It does not.** It sums
`<fn>_FRAMESIZE` only (FRAME_RE over EQUs, graph walk of JSR/FGX2_FARCALL).
Post-flip every live call level ALSO holds, on the same page:

- 3 bytes JSL return + **2 bytes PEI'd saved FP** (new in 3.1a) = 5 B/level,
- the **caller-pushed args** (live across the whole callee),
- mid-expression `g_s_delta` temporaries at call sites.

On a 256-byte page, a 15-deep chain is ~75 B of uncounted fixed overhead
before args. **Fix in 3.2:** per-edge cost = callee FRAMESIZE + 5 + args-bytes
(args statically known at the call site; conservative fallback 5 + 2×max-arity).
Do NOT launder this into the measured headroom pad — the pad is for what the
C graph *cannot* see (hand-asm libc/syscall/IRQ depth); C-call overhead is
deterministic and grows with depth, so a constant pad structurally cannot
cover it.

### F2 — HIGH (process): the full oracle was skipped when it was only partially blocked

3.1a landed gated by 8 fixtures + goldens that were **regenerated at the same
commit** (100% churn by design ⇒ goldens gate nothing at a flip milestone).
The full oracle was declared "blocked on 3.2," but only the *large-frame*
fixtures were expected to hang; the chunk cascade is a triage cost, not a
blocker. Worse, the "blocked" framing rests on "any frame >~256 B overruns" —
understated: it is the **sum of live frames + call overhead** that must fit,
so small-frame deep-chain fixtures may also hang, and the set of blocked
fixtures was unknowable without running. Running the oracle and enumerating
the hangs IS the 3.2 sizing measurement.

**Rule: when a gate is "blocked," run it anyway and produce the measured
exclusion list.** A partial gate with named, explained failures beats a
skipped gate every time — and at a milestone where the goldens were regenned,
the oracle was the only net left.

*(Review action: the full oracle was run as part of this review — results
below. Outcome: the fear was overstated — only 2 fixtures actually fail —
but the run surfaced F9, a worse failure mode nobody had predicted. Both
outcomes argue the same way: run the gate.)*

### F3 — MEDIUM (scope): two explicit scope items cut without surfacing

The maintainer's brief explicitly scoped (a) compiler heap-boxing for >~1 KB aggregates
and (b) `TASK_STACK_MAX_PAGES` 16→32. The plan cuts both as YAGNI
(heap-boxing deferred to elvis revival; 16→32 replaced by manifest-driven
per-binary sizing). Both rationales are defensible — but they were decided
unilaterally and never surfaced in the status report; they live only in a
plan-doc YAGNI section. Standing policy (stop-scope-ask; no silent feature
drops) applies to *scope* exactly as to port features. **Rule: an explicit
scope item you decide not to build gets a line in the report to the maintainer at
decision time — "cut X because Y, say if you want it" — not just a doc note.**

### F4 — MEDIUM (docs): plan self-contradicts on the stack default

§3.2 machinery says "Keep `TASK_STACK_MAX_PAGES` default 1" (conflating the
clamp — 16 — with the loader's 1-page default for offset-14=0); the YAGNI
section says "manifest-driven sizing with **default 16** is the mechanism."
A session implementing 3.2 from this doc can pick either. Also the static
checker slipped plan→"build in 3.0"→3.1a→"build at 3.1b" with no note,
despite the plan calling it "the load-bearing net" — deferral is right (no
`n,S` emission exists until 3.1b) but the doc should say so where it says
"build it in 3.0". **Fix both lines in the plan doc before starting 3.2.**

### F5 — LOW (latent): 16-bit `STZ _fcc_ssp+2` clobbers $BF every prologue

The prologue runs at M=16, so `STZ _fcc_ssp+2` zeroes **$BE and $BF**. $BF is
currently unallocated (spare below `_fcc_img0` = $C0) so this is benign — but
it is an undocumented per-call clobber; allocating $BF later produces a
per-function-entry heisenbug. **Fix: one comment line in the fcc_runtime.s DP
map reserving $BF as prologue-zeroed.** (Also fine: fold into the 3.3 band
delete, since `_fcc_ssp` dies then anyway.)

### F6 — LOW (stale comments): &local emitters still document the soft-stack bank

`emit.c:1986`, `:2426`, `:3808` still say &local bank = "the software-stack
bank (`_fcc_ssp+2`), NOT bank 0." The code is correct (it reads the cell,
which is now invariantly 0) but the comments assert the *opposite* of the new
invariant — misdirection for the next debugging session. Sweep when those
arms convert at 3.1b, or now.

### F7 — LOW (3.2 design nit): overflow guard misses the wrap case

`TSC/SEC/SBC #FRAMESIZE/CMP _fcc_stkfloor/BCC __stk_overflow`: if
FRAMESIZE > S (already catastrophic), the SBC wraps to a huge A and A ≥ floor
sails past the CMP. Branch on the **SBC borrow first** (`BCC __stk_overflow`
immediately after the SBC), then do the floor CMP.

### F8 — LOW (hygiene): leaked immortal watcher loops

Seven background `until ! pgrep -f run_runtime.py; do sleep; done` watchers
from the session were still alive at review time — the pattern matches the
watchers' *own* command lines, so they can never exit and they keep each
other alive. **Rules:** (a) self-excluding pattern, e.g.
`pgrep -f "[r]un_runtime"`; (b) one watcher, not one per glance; (c) never
pipe the runner through `tail` (existing ledger lesson — nearly repeated in
this review too).

## Full-oracle run on 3.1a (review-executed, 2026-07-07)

The review ran the full 373-fixture oracle opus deferred, then triaged.
Headline: **effectively 371/373 pass** — 3.1a codegen is broadly sound.

- Raw run: 356/373, 17 no-marker, ALL in chunk 011 (the chunk-cascade).
- Triage re-run of the 15 non-obvious names: **15/15 pass** — pure cascade
  victims of the two real hangs.
- **True failures (2): `ss_bigbuf` (main FRAMESIZE=4098) and `ss_recurse`
  (4 × 260 B recursion ≈ 1040 B)** — kB-scale overruns of the 1-page stack.
  These two are the 3.2 acceptance set: both must pass once the stack field
  lands.

### F9 — HIGH (discovered by running the gate): moderate overruns are SILENT

`g53_bigframe` (306 B), `ptr_bigframe` (304 B), and `p33_frame_deep` (264 B)
all **PASS** today — frames a few dozen–hundred bytes past the 256-byte page
scribble on whatever bank-0 memory lies below the task's stack page and exit
42 anyway. Only kB-scale overruns hang. Consequences:

- The docs' "large frames >256 B overrun … and HANG" model is wrong in the
  dangerous direction: **the common case is oracle-invisible corruption**, in
  a multi-task world that's another task's stack page or kernel bank-0 data.
- The exit-code oracle **cannot** gate this class. The 3.2 prologue overflow
  guard (and/or the static checker) is the only net that fails loudly —
  further evidence it is load-bearing, not optional hardening.
- At 3.2 acceptance, don't just re-enable the two hangs: assert the sizing
  actually covers `g53_bigframe`/`ptr_bigframe`/`p33_frame_deep` (e.g. via
  the guard trapping under a deliberately-undersized field, or a
  stack-canary probe), since "passes" proves nothing for them today.

## Guidance distilled (for the 3.2+ sessions)

1. **Measure, then size:** wire `fgx_ld.py` → `stack_measure.py` only after
   adding per-edge cost (F1). 3.2 acceptance set from this review:
   `ss_bigbuf` + `ss_recurse` flip to pass, AND the silent-overrun trio
   (`g53_bigframe`/`ptr_bigframe`/`p33_frame_deep`) is shown to be actually
   covered, not just "passing" (F9).
2. **Never skip a whole gate because part of it is expected to fail.** Run,
   enumerate, exclude with names and reasons (F2).
3. **Scope cuts go in the report, not just the plan** (F3).
4. **Before 3.2:** fix the plan's default-pages contradiction (F4), add the
   $BF reservation comment (F5), and use borrow-first guard order (F7).
5. At 3.1b: sweep the stale &local-bank comments (F6); build
   `tools/stack_check.py` alongside the FIRST family conversion, not after.

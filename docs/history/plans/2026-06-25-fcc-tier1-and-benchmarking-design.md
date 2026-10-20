# fcc codegen Tier 1 + a benchmarking paradigm — design

- **Status:** approved design, **rev. 2 (corrected after adversarial review)** → plan ready
- **Date:** 2026-06-25
- **Branch:** `feat/fcc-tier1-benchmarking` (tagged `pre-fcc-tier1-benchmarking` on `main`)
- **Origin:** evaluation of `examples/65816-llvm-mos` (an Apache-2.0 LLVM/Clang
  W65816 backend) for techniques adoptable into **fcc**, FGX's from-scratch
  C→Merlin32 compiler.
- **Related:** [`2026-06-24-dp-pressure-relief-design.md`](../../superpowers/specs/2026-06-24-dp-pressure-relief-design.md)
  (the DP-budget work this benchmark's DP manifest must align with),
  `docs/ROADMAP.md`, memory `project_fcc2_optimizing_backend`.

> **For future sessions — read this first.** This document captures (1) the full
> evaluation of `65816-llvm-mos` vs fcc, (2) a robust benchmarking paradigm for
> tracking object size / kernel size / DP usage / execution time across codegen
> upgrades, (3) the Tier 1 codegen work with exact file:line touch-points and
> *predicted* gains to be validated, and (4) the Tier 2/3 roadmap with the
> reference backend's algorithms as appendices. It is the canonical reference
> for the fcc optimization initiative.

> **Rev. 2 (post-review).** A multi-agent adversarial review (66 confirmed
> findings — see [`../audits/2026-06-25-fcc-tier1-plan-review.md`](../audits/2026-06-25-fcc-tier1-plan-review.md))
> corrected the measurement/test-wiring model. Key changes folded into this spec
> and the plan: the cycle harness uses **headerless** bench binaries (ORG $1000,
> markers in ASM) — fcc's FGX1 output can't be PC=$1000'd nor can C store the
> markers; **correctness is gated by `run_runtime.py` exit-code/`oracle.json`**,
> never by the cycle harness; the DP manifest is a **per-task page** (kernel can't
> collide) and the IMG span is **`$C0–$DF`**; T1.2 inlines **pow2 only** and the
> corpus gains **added int micro-benches** (the reference corpus doesn't exercise
> T1.2); and a **userland-rebuild release gate** is mandatory (peephole runs on
> every C binary). One real miscompile (const div/mod operand swap) was fixed in
> the plan before any code.

---

## 1. Executive summary

`examples/65816-llvm-mos` is a **real, working** LLVM/Clang backend for the WDC
65816 (~23k lines of W65816-specific C++, not just the design doc). On its own
benchmark suite it runs at **~0.62× Calypsi cycles geomean** (i.e. faster than
the best commercial 65816 C compiler) and produces smaller binaries.

The decisive finding is an **architecture mismatch** that dictates what is
adoptable and when:

| | **fcc (today)** | **65816-llvm-mos** |
|---|---|---|
| Model | **stack/accumulator memory-machine** | **register machine** + real allocator |
| Values live in | A + fixed *absolute* scratch (`_fcc_tmp_b`, `_fcc_long_hi`, `_fcc_ptr`) | A/X/Y + **16 "imaginary registers" in direct page** ($C0–$DF), graph-colored |
| Locals | **stack-relative `n,S`** only (8-bit disp + a far-path hack) | DP-promoted by access frequency; stack only as fallback |
| `a + b` | stash RHS→mem, pop LHS→A, `CLC; ADC _fcc_tmp_b` | carry-chain in registers |
| `x << 2`, `x * 8` (const) | **`JSR _fcc_shl16` / `JSR _fcc_mul16`** (subroutine call) | inline `ASL` / strength-reduced |
| Optimization | textual peephole, **3 patterns** (`peephole.c`) | ~20 MIR passes + dataflow |

fcc is currently **ORCA/C-tier** — precisely the baseline the reference project
set out to beat. That is the opportunity, and it splits cleanly into three tiers:

- **Tier 1 (this spec):** cheap, local wins in the existing peephole + emitters.
  Predicted ~5–15% smaller, ~10–20% fewer cycles geomean. Bounded — it is polish
  on a memory-machine.
- **Tier 2:** structural, no register allocator required — move fcc's hot scratch
  + a frame pointer into direct page. Program-wide constant win. (Coordinated
  with the DP-pressure-relief initiative.)
- **Tier 3 / fcc-2.0:** the register-machine backend (imaginary registers,
  allocator, register calling convention, hotspot promotion). This is where the
  "beat Calypsi" multiples live. The reference backend is a ready-made design;
  its algorithms are in the appendices.

**Licensing:** the reference repo is Apache-2.0. fcc is clean-room and FGX policy
is "fix the toolchain, don't work around it." We adopt **algorithms, idioms, and
the DP-budget map** — reimplemented — never pasted C++. Everything in Tiers 1–2
is "idea, reimplemented," which is clean.

---

## 2. Why the reference backend is fast (the four levers)

From `LLVM_65816_DESIGN.md §4`, confirmed in the passes:

1. **Register-width (REP/SEP) minimization** — each toggle costs 3 cycles;
   regions are coalesced to one width by a dataflow/peephole pass.
2. **Direct-page-as-register-file** — DP access is 1 byte + 1 cycle cheaper than
   absolute, ~2 cycles cheaper than stack-relative; the allocator treats DP slots
   as registers.
3. **Addressing-mode selection** — DP / abs / `abs,X` / long chosen per access.
4. **Native carry chains + idiom lowering** for 8/16/32-bit arithmetic.

fcc gets **lever 4 partially**, **none of 1–3 structurally**, and pays a
subroutine call for *every* shift and multiply (even by constants).

---

## 3. fcc's current codegen model (ground truth)

Established by reading the source (`toolchain/src/cc/`):

- **No AST / IR.** fcc is a **syntax-directed emitter**: `parse_expr.c` /
  `parse_stmt.c` call `emit_*` (`emit.c`, 96 functions) as they parse. Operands
  are materialized to code *as they are parsed*; there is no node to inspect after
  the fact.
- **Stack/accumulator machine.** Binary ops push LHS, emit RHS into A, then
  `emit_scalar_binop` (`emit.c:1833`) stashes RHS to `_fcc_tmp_b`, pops LHS into
  A, and calls the op emitter.
- **Fixed absolute scratch cells:** `_fcc_tmp_b`, `_fcc_long_hi`,
  `_fcc_long_b_lo/hi`, `_fcc_ptr` (+2 = bank), `_fcc_fp`. A `long`(i32) = A(lo) +
  `_fcc_long_hi`. A pointer = A(offset) + `_fcc_ptr+2`(bank).
- **Locals are stack-relative `n,S`** (`emit.c:110-176`), 8-bit displacement,
  with a "far path" (`slot_needs_far`, `emit.c:104`) for frames > 255 bytes.
  **fcc uses zero direct page** for user data.
- **Everything heavy is a libcall:** 16-bit `*`/`/`/`%`/`<<`/`>>` →
  `_fcc_mul16`/`_fcc_divs16`/`_fcc_modu16`/`_fcc_shl16`/`_fcc_shr16`
  (`emit.c:1969-2045`). All `long` ops → `_fcc_long_*`. (The 65816 has **no
  hardware multiply**, so variable×variable mul/div must stay libcalls.)
- **SEP/REP emitted inline** around every 8-bit (char) op (`emit.c` ~40 sites) →
  many redundant toggles.
- **Existing textual peephole** (`peephole.c`, 345 lines) with solid
  infrastructure: line parser, NZ-liveness (`nz_dead_after`, `peephole.c:196`),
  label-barrier scans, and **3 patterns**: `pat_bra_to_next`,
  `pat_staload_forward`, `pat_repsep_adjacent` (adjacent-only). Invoked from
  `main.c:415` (`peephole_optimize`).
- fcc already has the **inline strength-reduction idiom** in
  `emit_scale_index_by` (`parse_expr.c:1899`: `ASL` for ×2, `ASL ASL` for ×4,
  `_fcc_mul16` otherwise) — but only wired to pointer-stride scaling, not general
  `x<<k` / `x*k`. **This is the template for T1.2.**

---

## 4. The benchmarking paradigm

**Decision (user):** system-wide budget dashboard; corpus = ported reference
microbenchmarks (3-way comparable vs Calypsi + llvm-mos); advisory now, gate
later.

The harness is mostly **integrate + extend + persist**, not greenfield —
existing pieces are reused.

### 4.1 What already exists (reuse, don't rebuild)

- `toolchain/tests/metrics.sh` — deterministic, emulator-free **size** tracker:
  per-fixture bytes + non-comment asm-line count over `*.expected.bin`/`.s`,
  totals, and a `compare` mode (before/after deltas, %, top-20 shrinks). Writes
  to `/tmp` (ephemeral). → reuse the size/compare logic.
- `examples/65816-llvm-mos/scripts/runInMameCycles.sh` — **cycle** harness: load
  binary at `$1000`, set CPU state, poll memory markers `$025000==0xA1A1` (START)
  / `$025002==0xA2A2` (DONE), capture `emu.time()` deltas → `cyc_per_call`; plus
  a `--sample` PC-profiler that joins a linker `--map` for per-function
  attribution. → port to an fcc-native harness.
- `toolchain/tests/run_runtime.py` — existing headless MAME exit-code harness
  (correctness). → reuse for correctness gating, share its MAME plumbing.
- `build.sh` already emits `{"kernel_bytes": N}` (`build.sh:58,99,642`). → feed
  the system-size view.
- `lib/mame_env.sh` — shared MAME environment. → reuse.

### 4.2 Architecture

```
toolchain/bench/
  fbench.py            # orchestrator: snapshot | compare | report
                       #   headless; per-test N/Total progress + ETA (CLAUDE.md closed-loop)
  corpus/              # ported reference microbenchmarks (.c), marker-wrapped
    bsearch.c sumOfSquares.c strcpy.c popcount.c dotProduct.c djb2Hash.c
    memcmp.c strLen.c bubbleSort.c fib.c           # README's 10 first; expand later
  _wrap_bench.s        # HEADERLESS bench wrapper (ORG $1000); emits START/DONE markers in ASM
  dp_budget.toml       # per-task USER DP reservation manifest — KEYSTONE
  baselines/
    toolchain-v0.16.0-pre-tier1.json  # committed snapshots, keyed by TOOLCHAIN sha
  reports/             # generated (gitignored)
  README.md            # how to run / add a benchmark / update baselines
```

`fbench.py` is the single entry point (Python, matching `run_runtime.py`).

### 4.3 The four metrics — exact definitions

| Metric | Definition | Source / mechanism | Tier 1 relevance |
|---|---|---|---|
| **Binary/object size** | per-corpus `.o` bytes, linked `.bin` bytes, non-comment asm-line count | extend `metrics.sh`; linker map | **primary** — REP/SEP + INA folds shrink it |
| **Execution time** | total cyc between START/DONE markers ÷ ITERS, @ 1.023 MHz (slow) | **headerless** bench binary loaded raw at $1000; markers emitted in ASM; `emu.time()` captured at the marker **writes** (`install_write_tap`, NOT frame poll — frame poll quantizes to ~17050 cyc) | **advisory** (never gates) |
| **DP usage** | bytes of the **per-task user DP page** used by fcc code + overlap check within that page | `dp_budget.toml` + user-binary DP refs (**fcc = 0 today**) | tracked-but-flat in T1; live in T2/3 |
| **Kernel / system size** | `fgx.bin` kernel bytes + sum of an explicit **fcc-built** userland bin list (not `disk_src/**`, which is non-deterministic) | `build.sh` `kernel_bytes` + fcc-tool list | passive guardrail in T1 |

### 4.4 The DP-budget manifest (`dp_budget.toml`) — per-task USER page

**Correction (rev. 2):** FGX gives each task its **own** bank-0 direct-page page,
distinct from the kernel's and GS/OS's pages — so an fcc-vs-kernel DP *overlap*
is architecturally impossible. The manifest therefore scopes to the **per-task
user DP page** that fcc-compiled code shares with its own crt0/libc runtime;
kernel/GS-OS pages are listed informational-only. The overlap check runs **within
the user page**. What makes Tier 2/3 safe is keeping fcc's growing DP claims
(scratch, then the imaginary-register pool) within that one page's budget.

- **fcc runtime scratch** (`_fcc_*`) — today absolute; candidates to move to DP in
  Tier 2 (reference scratch range `$E0–$EF`).
- **fcc imaginary-register pool** (future, Tier 3) — reserve **`$C0–$DF`** (16 i16
  regs; `$DF` = IMG7 high byte — note this is `$C0–$DF`, *not* `$C0–$DE`).
- **fcc i64/double + frame-pointer** (Tier 2/3) — reference `$F0–$F1`, `$F6–$F7`.
- *Informational only* (separate pages, never overlap user code): FGX kernel DP,
  GS/OS+firmware DP. Seed exact bounds from `docs/memory-map.md` + the DP-relief
  design when sourced; not required for T1 (fcc user-DP usage = 0).

`fbench` reads this manifest and reports user-page usage + intra-page overlaps.

### 4.5 Persistence & comparison model

- `fbench snapshot <tag>` → writes `baselines/<tag>.json`, stamped with the
  **toolchain submodule** SHA (codegen lives in `toolchain/`, not the FGX
  superproject) + a `-dirty` marker; baseline name is toolchain-version + intent
  (e.g. `toolchain-v0.16.0-pre-tier1.json`) — **not** `v0.16.0.json`, which would
  collide with the released tag and record a feature-branch SHA.
- Baselines are **committed** (not `/tmp`) → reproducible cross-session/machine.
- `fbench compare <base.json>` → delta report covering **size, cycles, DP, AND
  system** (the v1 compare did size only). The Calypsi/llvm-mos reference columns
  are **indicative only** — they came from a different harness (ORG/ITERS/inputs/
  calling-convention differ) and are not a controlled comparison; the authoritative
  metric is the fcc **baseline-vs-current** delta.
- `fbench report` → run all four, print a unified markdown scoreboard, write
  JSON. **Advisory** — never fails the build yet.

### 4.6 Advisory → gate path (later)

Once baselines are stable, flip `fbench` into a gate from `release.sh`/CI:
fail on size or cycle regression beyond a per-metric threshold. Until then,
report-and-review only (matches starting-from-scratch reality; avoids
false-positive friction).

### 4.7 Corpus porting notes

- Port the README's 10 integer-centric benchmarks first (verbatim bodies, inputs
  matching their `benchInputs()` so the indicative ref columns line up). Defer
  float/double ones (`dadd/ddiv/dmul`, `mandelbrot`, `particles`) until fcc float
  coverage is confirmed. If a bench can't compile under fcc, **STOP and scope it**.
- Each `.c` is a self-contained `int main(void){ …hot loop ×ITERS… }` with **no
  marker code in C** — the headerless `_wrap_bench.s` emits START/DONE in assembly
  around `JSR main` (fcc cannot store to bank 2 from an integer-constant pointer).
  Use `ITERS ≥ 2000`.
- **Add T1.2-exercising micro-benches** (`t12_shift`, `t12_mul`, `t12_divmod`)
  using **`unsigned int`** (not `long`): the ported reference corpus does NOT
  exercise constant shift/mul/divmod on int, so without these the T1.2 wins are
  unmeasurable (the reference benches use unsigned-long hashing / signed `(lo+hi)/2`).
- **No silent corpus truncation** — `fbench` logs every skipped bench with a reason.

---

## 5. Tier 1 codegen scope (with file:line touch-points)

Split by **implementation surface** (determines risk). Each sub-phase is its own
plan → implement → verify (goldens + correctness + `fbench compare`) cycle.

### T1.1 — Peephole extensions (`peephole.c`, textual, lowest risk)

| Item | fcc today | Change | Reference | Risk | Status |
|---|---|---|---|---|---|
| Extended REP/SEP coalescing | `pat_repsep_adjacent` cancels only *adjacent* toggles (`peephole.c:291`) | add **M-neutral whitelist** + fixpoint loop; cancel toggles separated by M-neutral ops | `W65816SepRepCleanup.cpp:360-445` | Low | **DROPPED 2026-06-26** |
| `CLC;ADC #k`→`INC`×k / `SEC;SBC #k`→`DEC`×k | emits `CLC;ADC #n` everywhere (`emit.c:116,877,884…`) | new `carry_dead_after` scan (mirror of `nz_dead_after`) + rewrite for k∈[1,2] | `W65816SepRepCleanup.cpp:207-234` | Low | **LANDED 2026-06-26** |
| Invert-cond-to-fallthrough | `pat_bra_to_next` only (`peephole.c:272`) | `beq X; bra Y; X:` → `bne Y` when X is next label | `W65816BranchExpand.cpp:253-300` | Low | **DROPPED 2026-06-26** |

> **Empirical Step-0 result (2026-06-26).** Scanning raw (pre-peephole) fcc emit
> across 38 char-heavy programs + all 280 fixtures found **zero** removable
> extended REP/SEP `#$20` windows (fcc only toggles M-width immediately around an
> M-sensitive data op, which is never M-neutral) and **zero** `Bcc L; BRA L2; L:`
> idioms (fcc emits long conditionals as `Bcc *+5; BRL target` — a short branch
> over a full-range BRL — which the textual pattern can't safely collapse without
> byte-range analysis). Both passes would be dead, untested bug-surface →
> **dropped**, per the plan's "drop if it never fires" gate. The `CLC;ADC`→`INC`
> fold has **183 real sites** (175 `CLC;ADC #(1|2)`→`INC` + 8 `SEC;SBC`→`DEC`,
> carry-dead) incl. the strcpy/strLen/memcmp/djb2Hash hot loops, so only it landed.
>
> **Two corrections folded in while landing:** (1) the mnemonic is **`INC`/`DEC`**
> (implied accumulator), NOT `INA`/`DEA` — **merlin32 v1.1.10 rejects INA/DEA**
> (`[Error] Unknown line 'INA'`); the golden+merlin32 gate caught it. (2) `REP`/`SEP`
> are **not** carry-writers (fcc only toggles M/X width), so they are excluded from
> `writes_carry` and treated carry-neutral — otherwise `carry_dead_after` would
> over-claim and fold a `CLC;ADC` whose carry is read across a width toggle
> (regression test `clcadc_keep_carry_across_sep`).

### T1.2 — Constant-aware arithmetic lowering (`parse_expr.c`, parser peek; biggest speed win)

Requires a **literal-RHS peek** before the generic `emit_scalar_binop` path,
because fcc has no AST. Conservative peek: RHS token is an integer literal AND the
following token terminates the operand (`;`, `)`, `,`, a lower-precedence
operator) → consume + emit inline; else fall back to the existing libcall path.
Reuse the `emit_scale_index_by` idiom (`parse_expr.c:1899`).

| Item | fcc today | Change | Risk |
|---|---|---|---|
| Inline constant shift `x<<k`, `x>>k` | always `JSR _fcc_shl16/_fcc_shr16` (`emit.c:2025-2045`) | in `parse_shift_expr` (`parse_expr.c:1992`), peek literal RHS → inline `ASL`/`LSR`×k on A (skip push/pop/stash entirely) | Med |
| Constant-mul strength reduction `x*k` | always `JSR _fcc_mul16` (`emit.c:1969`) | in `parse_mul_expr` (`parse_expr.c:1874`), peek literal RHS → `ASL` (pow2) / shift-add chain | Med |
| Constant unsigned `/`,`%` by pow2 | always `JSR _fcc_divu16/modu16` | peek literal pow2 → `LSR`×k / `AND #(k-1)` (unsigned only) | Med |

### T1.3 — Idiom lowering (`emit.c` cmp/sext) — **DEFERRED** (decided 2026-06-25)

**Not in this round.** Revisit after T1.1+T1.2 land and are measured; the data
decides whether it earns its place.

- Signed-compare via `EOR #$8000` sign-flip (`W65816ISelLowering.cpp:511-540`).
- Branchless i8 sign-extend `(x^0x80)-0x80` (`W65816ISelLowering.cpp:983`).
- **First verify** fcc's current `emit_cmp_*` (`emit.c:2210+`) and sext aren't
  already adequate — these may be no-ops.

### Explicitly out of Tier 1 (set expectations)

The memory-machine model itself: operand materialization to memory, stack-relative
locals, and **variable×variable** mul/div + all `long` ops staying as libcalls.
The 65816 has no hardware multiply, so `i*i` (sumOfSquares) and `a[i]*b[i]`
(dotProduct) get **no Tier-1 speedup**. Those need Tier 3.

---

## 6. Predicted gains (hypotheses — the harness validates them)

Predictions with reasoning, **to be confirmed by `fbench`** (the reason the
harness is built first). Cycle facts (16-bit M, slow mode): `JSR`+`RTS`=12,
`_fcc_mul16`≈120–200, `_fcc_shl16`≈25–50, `ASL`/`LSR`=2, `REP`/`SEP`=3 (2 B each),
`CLC;ADC #k`=5 (3 B), `INC` (implied-A)=2 (1 B).

### Per-operation

| Operation | Before | After | Win |
|---|---|---|---|
| `x<<3` (const, int) | ~40 cyc + push/pop/stash, ~11 B at call site | 3× `ASL` = 6 cyc, 3 B | ~7× |
| `x*8` (const pow2, int) | ~150 cyc (`_fcc_mul16`) | 3× `ASL` = 6 cyc | ~25× |
| `(unsigned)x/8`, `%8` | ~150 cyc libcall | `LSR`×3 / `AND #7` | large |
| redundant `REP/SEP` pair | — | removed | −6 cyc, −4 B (DROPPED — never fires) |
| `CLC;ADC #1` → `INC` | 5 cyc, 3 B | 2 cyc, 1 B | −3 cyc, −2 B |

> **Scope (rev. 2):** T1.2 inlines **pow2 only** — `x*10` (non-pow2) is **not**
> inlined; it stays `_fcc_mul16`. Inline div/mod is **unsigned pow2 only**. Inline
> `>>` is **unsigned only** (signed `>>` stays the libcall). Earlier "shift-add for
> `x*10`" framing is dropped.

### Per-benchmark coverage (rev. 2 — what the corpus actually measures)

| Change | Where it shows | Notes |
|---|---|---|
| **T1.1** REP/SEP coalescing | — | **DROPPED** — 0 collapsible pairs in real fcc output |
| **T1.1** INC fold | any bench with `i++`/`j++`/`p++` loop counters | `CLC;ADC #1`→`INC` (implied-A; merlin32 rejects INA) when carry dead |
| **T1.2** const shift/mul/divmod | **only the added `t12_*` int micro-benches** | the ported reference corpus is unsigned-**long** hashing / signed `(lo+hi)/2` → T1.2 (int/unsigned-int) does **not** fire there |
| (no effect) | djb2Hash, popcount (unsigned long), sumOfSquares/dotProduct (`_fcc_long_mul`, var×var) | flat — long ops + no HW multiply |

### Aggregate prediction

- Binaries **~5–15% smaller** on T1.1-affected code (REP/SEP + INA); inline pow2
  shift/mul is size-neutral-to-smaller (cap inline expansion as a size knob).
- T1.2 micro-benches: **multiples faster** on the inlined op; whole-program effect
  depends on how often int constant shift/mul appears in real userland.
- The "beats Calypsi" (~0.62×) territory is a **Tier 3** outcome, **not** Tier 1.

### Predicted-vs-actual tracking (fill in as phases land)

| Phase | Date | Size Δ (pred → actual) | Cyc Δ (pred → actual) | DP Δ | Notes |
|---|---|---|---|---|---|
| baseline (toolchain-v0.13.0-pre-tier1) | 2026-06-25 | — | — | 0 | `toolchain-v0.13.0-pre-tier1.json` (+ `.kernel.json`) |
| T1.1 peephole | 2026-06-26 | −5–15% on affected code → **−0.38% userland (−854 B), −71 asm lines** | −3 cyc/fold → **memcmp −4.1%, strLen −3.4%, strcpy −2.9%, djb2Hash −0.5%** (µs/call) | 0 | Only `CLC;ADC`→`INC` landed (183 sites); extended-REP/SEP + invert-cond **dropped** (0 candidates). Snapshot `t1.1-peephole.json`. 282/282 goldens, 263/263 runtime, adversarial review SAFE. |
| T1.2 const-arith | 2026-06-26 | size-neutral → **userland ~flat (−18 B); affected sites shrink** (LDX/STX vs PHA…PLA) | multiples-faster on the inlined op → **t12_mul −76% (µs/call) / −80% (cyc), t12_divmod −90%, t12_shift −38%** | 0 | const int `<<`/pow2 `*`/unsigned pow2 `/`,`%`. Rarely fires in real userland (long/var/stride code) → whole-program userland flat; the win lands on constant-int-arith hot paths. Baseline `t1.2-const-arith.json`. goldens 285/285, oracle 266/266. |
| T1.3 idioms | | — | — | — | DEFERRED 2026-06-25 — revisit post-T1.2 |

---

## 7. Build sequence / next steps

1. **T1.0 — Harness first** (cannot predict-or-prove without it):
   `fbench` skeleton → size (reuse `metrics.sh`) → **headerless** cycle harness
   (`_wrap_bench.s` + write-tap port of `runInMameCycles.sh`) → `dp_budget.toml`
   (per-task page) → commit `baselines/toolchain-v0.16.0-pre-tier1.json`.
   **Snapshot the pre-change baseline.** (Size-only is acceptable if MAME absent —
   cycles are advisory.)
2. **T1.1 peephole** → snapshot → `fbench compare` → record actual vs predicted.
3. **T1.2 const-arith** (incl. the `peek_tok()` enabler) → snapshot → compare.
4. **T1.3 idiom lowering** — **DEFERRED** (revisit after T1.2 data).
5. Per step: TDD against goldens (`regen_goldens.sh` + review) AND the **exit-code
   oracle** `run_runtime.py` (`oracle.json`), then `fbench` (advisory). Follow FGX
   discipline + the **codegen-change release gate** (rebuild all C userland +
   run their behavior manifests before release — peephole runs on every binary).

---

## 8. Tier 2 — structural (no register allocator) [summary]

Move fcc's hot scratch + a frame pointer into **direct page**:

- Relocate `_fcc_tmp_b`, `_fcc_long_hi`, `_fcc_ptr`, `_fcc_fp` from absolute to DP
  → every arithmetic/pointer op 1 cycle + 1 byte cheaper, program-wide, **no
  allocator**. Use the reference DP map (`W65816RegisterInfo.td:48-75`;
  scratch $E0–$EF, FP $F6–$F7) and GS/OS-safe regions as a template.
- Adopt the **DP-frame-pointer-for-large-frames** heuristic
  (`W65816FrameLowering.cpp:168-181`) — maps directly onto fcc's existing far-path
  (`emit.c:104`).
- Gated by `dp_budget.toml` (no collision with kernel/GS-OS) — this is where the
  DP-usage metric turns live; coordinate with the DP-pressure-relief initiative.

---

## 9. Tier 3 / fcc-2.0 — the register machine [roadmap]

When fcc grows a real IR + allocator (memory `project_fcc2_optimizing_backend`),
the reference backend is the worked example. Adopt as **algorithms**:

- **Imaginary-register file in direct page** as an allocatable register class
  (App. B).
- **Frequency-based hot-slot promotion** (static weighted access count) (App. B).
- **Liveness/value-equivalence stack-slot merging**; **X-as-overflow-spill**
  (App. B).
- **Calling convention with first arg in A** + DP-backed arg slots (App. D) vs
  fcc's all-on-stack (`emit.c:1126`).
- **Global REP/SEP width dataflow** (vs the local peephole) once a CFG exists
  (App. A).
- **i32 strategy:** decompose to i16 pairs early; narrow `__mulsi3`→`__umulhisi3`
  when high bits provably zero; undo-LSR to prefer `abs,X` over pointer-walking
  (App. C).

### Correctness item worth checking now (any tier) — demoted to a regression guard

**Negative-index indirect addressing** (`W65816NegYIndY.cpp`): `(ptr,S),Y` does a
*24-bit* add, so a negative Y can cross a bank boundary. **Rev. 2 correction:** the
reference's `abs,X` rewrite pass is **DISABLED**; the reference's *live* fix is
indirect-long `[dp],Y` with a zeroed bank byte — which fcc **already mirrors**
(`_fcc_ptr+2` bank handling). So generic `arr[j-1]` is **not** exposed in fcc.
Action: keep a **regression guard** test (`arr[j-1]` swaps, bubble-sort style) to
confirm fcc stays correct; do not port the disabled `abs,X` pass.

> **Explicitly avoided (known reference regressions, do NOT port):** the reference
> backend disables several passes that caused miscompiles — `CMP #0` elimination,
> PHI store-forwarding, narrow PHI-copy collapse, and the `abs,X` NegY rewrite.
> fcc should not adopt these.

---

## Appendix A — REP/SEP width management (reference algorithm)

Source: `W65816SepRepCleanup.cpp` (1131 lines), `W65816WidenAcc16.cpp`,
`W65816RegisterInfo.td`, `W65816InstrFormats.td`.

- **Width model:** parallel register classes share one physical register —
  `Acc8`/`Acc16` over A, `Idx8`/`Idx16` over X/Y (`RegisterInfo.td:95-98`). Each
  instruction encodes its required M/X mode in TSFlags (`InstrFormats.td:14-21`).
- **`SepRepCleanup` is a local, multi-pass peephole** run post-PEI (NOT global
  dataflow). Key passes:
  - **Adjacent toggle coalescing** (`:332-358`): `REP #x` … (debug only) …
    `SEP #x` → erase both.
  - **Extended gap coalescing** (`:360-445`): cancel a `REP`/`SEP` pair separated
    only by **M-neutral** instructions (index ops LDX/LDY/STX/STY, INX/DEX/INY/DEY,
    PHX/PHY/PLX/PLY, CLC/SEC, branches, NOP). **fcc port caveat:** PHP/PLP are
    **NOT** M-neutral (they carry the M/X bits in P) — exclude them; and apply only
    to `#$20` (M) toggles, never `#$10` (X) over X-width-sensitive index ops.
    **Fixpoint loop** restarts after each deletion to catch nested pairs.
  - **`CLC;ADC #k`→`INA`/`DEA`** for small k when **carry dead** (`:207-234`).
    fcc port: carry-liveness is **carry-only** (fcc emits no `BVC/BVS`); treat any
    following `ADC/SBC/ROL/ROR/BCC/BCS/PHP/XCE` as a carry consumer, and `CLC/SEC/
    CMP/CPX/CPY/REP/SEP/PLP`/return as carry-dead. fcc's `long` add is a libcall
    (opaque), so the rule is simply "stop at the first carry reader."
  - Plus: LDAi8imm hoist, PHP/PLP copy hoist/sink, i32 store-bypass, dead
    TAX/TXA elimination, redundant `LDY #0` elimination.
- **`WidenAcc16`** (pre-RA): promote single-def Acc16 vregs to `Wide16`
  (A + IMG0–15) so the allocator can place them in DP imaginary registers instead
  of spilling.
- **Portability:** the toggle-coalescing + INA-fold patterns are
  **algorithm-portable** to fcc's textual peephole (T1.1). Fixpoint-restart and
  flag-liveness scanning are the two principles to carry over.

## Appendix B — Direct-page imaginary-register file (reference algorithm)

Source: `W65816StackRelToImg.cpp` (3342), `PromoteFiToImg.cpp`,
`ImgCalleeSave.cpp`, `StackSlotMerge.cpp`, `StackSlotCleanup.cpp`, `SpillToX.cpp`,
`RegisterInfo.td`.

- **IMG0–IMG15** = 16 i16 DP slots — IMG0–7 at slot bases `$D0,$D2,…,$DE`,
  IMG8–15 at `$C0,$C2,…,$CE` (`imgRegToDP` in `RegisterInfo.cpp`). The full
  inclusive byte span is **`$C0–$DF`** (32 bytes; `$DF` = IMG7's high byte) — so
  the manifest reservation is `$C0–$DF`, **not** `$C0–$DE`. Declared as register
  class `Img16` (`RegisterInfo.td:48-110`); `Wide16` = A + all IMG. The greedy
  allocator treats them as ordinary registers; IMG↔A moves are `LDA/STA dp` (4 cyc).
- **Promotion pipeline (post-PEI):** StackSlotMerge (collapse value-equivalent
  PHI-copy slots) → StackRelToImg (count accesses per logical stack offset, sort,
  promote top-8 to IMG0–7, rewrite `*_StackRel`→`*_DP`) → peepholes
  (`LDA;INA;STA`→`INC_DP`, store-forwarding, PHA-bracket elision) → ImgCalleeSave
  (callee-side save/restore of any written IMG8–15 under a single PHA/PLA
  bracket).
- **Heuristics:** promote offsets with **≥3 accesses**, cap 8 promoted / 16 hot;
  skip arg slots and ptr-deref slots.
- **SpillToX:** `STAfi … LDAfi` (same slot, X free in gap) → `TAX … TXA`
  (4 cyc + 2 B saved).
- **Calling convention:** DP and DBR callee-saved (`RegisterInfo.cpp:226`);
  IMG0–7 caller-save; IMG8–15 pseudo-callee-saved via ImgCalleeSave.
- **Portability to fcc-2.0:** the **access-count promotion**, **value-equivalence
  slot merging**, and **X-as-overflow** are algorithm-portable once fcc has
  liveness + a slot model. Needs: a DP-slot pool, register classes, post-RA
  rewrite pass.

## Appendix C — Peephole / idiom passes (reference patterns)

Source: `UnLSR.cpp`, `I32IncFold.cpp`, `NarrowI32Mul.cpp`, `NegYIndY.cpp`,
`ABridgeViaX.cpp`, `LowerWide32.cpp`, `TiedDefSpill.cpp`, `BranchExpand.cpp`.

- **I32IncFold** (EASY/textual): `LDA lo; ADC #1; STA lo; LDA hi; ADC #0; STA hi`
  → `LDA lo; INA; STA lo; BNE skip; LDA hi; INC; STA hi; skip:` — uses Z surviving
  STA. ~13 cyc saved common case. (Tier 1 candidate for `long`++ later.)
- **NegYIndY** (EASY/correctness): negative-Y `(sr,S),Y` 24-bit add bug →
  compute addr in A, use `abs,X`. **Check fcc for the same bug.**
- **NarrowI32Mul** (HARD): `__mulsi3`→`__umulhisi3` when high 16 bits provably
  zero (needs KnownBits/SCEV) — ~140 cyc saved. fcc-2.0.
- **UnLSR** (MEDIUM): undo LSR pointer-walking back to `abs,X` indexing — better
  on 65816. fcc-2.0.
- **BranchExpand** (MEDIUM): long-conditional relaxation (`inv Bxx; BRL`) +
  invert-to-fallthrough (T1.1 #3) + drop trailing `BRA next`.
- **LowerWide32 / TiedDefSpill / ABridgeViaX**: SSA/MIR-dependent — fcc-2.0 only.

Overall i32 strategy: decompose to i16 pairs early; carry chains; narrow mul;
smart inc; prefer indexing over pointer-walk.

## Appendix D — Instruction selection, calling convention, addressing (reference)

Source: `W65816ISelLowering.cpp` (3914), `InstrInfo.td`, `FrameLowering.cpp`,
`CallingConv.td`, `PreSpillCrossCall.cpp`.

- **Calling convention:** first arg in **A**, rest on stack right-to-left;
  i32 ret = A(lo)+X(hi); i64 adds Y + DP $F0–$F1. Stack args promoted to i16 for
  uniform 16-bit loads. (vs fcc's all-on-stack.)
- **Addressing-mode selection:** `memfi` ComplexPattern → `LDAfi/STAfi/ADCfi`
  pseudos that `eliminateFrameIndex` lowers to `d,S` or `[dp],Y` by offset size.
  Tied accumulator ALU pseudos (ADCfi/SBCfi/ANDfi/…) keep ops 2-operand.
- **Notable lowerings:** carry-chain i32 add/sub; signed compare via `EOR #$8000`
  (T1.3); branchless i8 sext (T1.3); `Wide32(Wrapper(g),0)`→DBR-relative
  `lda g`; `global+index`→`STA_AbsX`.
- **Frame lowering:** always enter `REP #$30`; **preserve A** (arg0) through
  prologue via TAY; DP frame pointer ($F6–$F7) for frames > 200 B or VLAs (Tier 2
  template).
- **PreSpillCrossCall:** if >4 call sites and an Acc16 vreg lives across a JSL,
  pre-spill before RA (avoids "out of registers"). fcc-2.0.

---

## Appendix E — Process / how to resume

- **Evaluation method:** four parallel `Explore` sub-agents read the reference
  backend (REP/SEP, DP register file, peephole idioms, isel/calling-conv); fcc
  mapped via jCodemunch + direct reads. Full traces condensed in App. A–D.
- **To resume:** read this spec → check the predicted-vs-actual table (§6) for
  the last landed phase → continue the build sequence (§7). Harness usage lives in
  `toolchain/bench/README.md` (created in T1.0).
- **Reference tree:** `examples/65816-llvm-mos/src/llvm/lib/Target/W65816/`
  (Apache-2.0; algorithms only, no code copy). Its benchmark suite +
  Calypsi/llvm-mos numbers are in `examples/65816-llvm-mos/{benchmarks,README.md}`.

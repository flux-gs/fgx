# fcc-2.0 Phase 3 — Increment 0: spill/reload measurement results

**Date:** 2026-06-29 · **Toolchain branch:** `feat/fcc2-p3-global-regalloc`
(off v0.18.0) · **Status:** measurement complete; **a re-scope decision is open**
(no allocator built — this spike exists to decide *whether* to build it).

## TL;DR

**The ≥15% gen-code SIZE-band DoD is NOT reachable by the global allocator (or by
spill/reload elimination generally).** Direct measurement over 21 real C userland
tools (189 functions): the structural spill/reload the allocator could remove is
**≈2% of gen-code (ceiling), ≈0% reachable now (floor)** — 4–7× short of 15%, and
consistent with the earlier re-grounding's independent asm-level ~3% optimistic
estimate. The spike did its job: it proved this **before** a large allocator was
built.

## Method (read-only, byte-identical)

An `FCC_P3_STATS`-gated read-only pass (`ir_p3_stats` in `toolchain/src/cc/ir.c`,
after `ir_allocate`) attributes removable spill/reload bytes to levers L1–L5 over
the final IR, bracketed floor/ceiling. It mutates no IR (with the env unset it
does not run; `run.sh` 303/0, `FCC_P3_STATS` on-vs-off `.s` identical). Aggregated
by `toolchain/bench/p3stats.py`.

- **Reload = A-clobbered between producer and reload only.** A store→load across
  A-preserving ops is already removed by the shipped textual peephole
  (`pat_staload_forward`), so counting it would inflate the win. This gate makes
  the numbers the **incremental** structural spill/reload — exactly the class the
  re-grounding flagged as removable only by global register allocation.
- **Floor** = within-BB + peak-live temps ≤3 (a register provably free):
  "allocator-reachable with current coverage." **Ceiling** = any no-redef reload,
  assuming full barrier coverage + unlimited DP-IMG spill.

**Corpus:** the real single-file C tools built by the shipped FGX2 recipe
(`build_userbin_fgx2_c`): sed, ed, tr, cat, df, cal, man, more, head, fold, cp,
wc, uniq, cmp, strings, ul, uname, tput, false, dirname, basename (od skipped —
multi-file). 189 functions.

**Denominators.** The ≥15% DoD is *gen-code* reduction, so the denominator is the
fcc-generated code only:

| denominator | bytes | note |
|---|---|---|
| **fcc-generated code** (`<tool>.s`) | **103,749** | the DoD denominator |
| whole seg0 (incl. hand-asm libc/runtime) | 340,503 | fcc can't change 70% of this |

## Results (vs 103,749 gen-code bytes)

| lever | count | bytes | % gen-code | meaning |
|---|---:|---:|---:|---|
| **FLOOR** (allocator now) | 4 | **8** | **0.01%** | within-BB, register free |
| **CEILING** (allocator, full coverage) | 884 | **2023** | **1.95%** | total incremental spill/reload |
| coverage-gated gap (ceil−floor) | — | 2015 | 1.94% | 99.6% needs barrier coverage, not just the allocator |
| L3_complex (binop RHS stash) | 945 | 1890 | 1.82% | **IRREDUCIBLE** — no `ADC <register>` on the 65816 |
| L3_leafmiss (binop stash) | 217 | 434 | 0.42% | fold-reachable (`ir_select` coverage), not allocator |
| L4 push overflow | 1114 | 0 | 0% | PHA == TAX bytes — **confirmed not a size lever** |

**Where the ceiling is blocked** (what coverage work would be required, and how
little it would buy): the dominant blocker is **IR_TEXT barriers**
(labels/branches/control flow + un-lifted raw ops) — `L1_xbar_text` 271,
`L2_xbar` 578, `L5_sand_text` 714 distinct barriers. Deref/call/index are minor
(`L5_sand`: deref 42, call 38, index 21). So even the headline "structure the
deref/array/call barriers" coverage work targets <15% of the (already tiny)
recoverable mass.

## Validation (the maintainer's rigor requirement)

- **Determinism:** identical re-run (ceiling 884 / 2023 both times).
- **Asm cross-check (address-resolved):** IR L3 stashes (1162) vs real
  `STA _fcc_tmp_b` in the fcc-generated asm (**1812**). The IR-level count is a
  **subset** — ~36% more `_fcc_tmp_b` traffic lives in IR_TEXT-lowered ops
  (var×var muls, comparisons, divmod), all of which are equally irreducible. The
  IR-level measurement therefore **under-counts** total spill/reload traffic (it
  sees only structured ops), in the expected direction.
- **Reconciliation with the re-grounding:** adjusting the recoverable ceiling for
  the ~1.5× IR-vs-asm under-count gives ~3–4% — matching the re-grounding's
  independent static asm-level "~3% optimistic." Two independent methods agree:
  **single-digit %, nowhere near 15%.**

## Why ≥15% is architecturally unreachable here

The accumulator-machine codegen's gross load/store traffic (value_ldst ≈48.5% per
the re-grounding) is mostly **necessary** loads/stores, not redundant spill/reload.
The redundant, removable part is ~2–4%. The biggest single store bucket is in fact
the **`_fcc_ptr` 24-bit pointer-setup dance** (`STA _fcc_ptr` / `+2` / `[_fcc_ptr]`
≈1584 stores in sed alone) — which the re-grounding already flagged as largely
irreducible (no 65816 `[n,S]` 24-bit mode; partially addressed by the B1b/B1c
pointer-promotion track). There is no ≥15% SIZE lever hiding in register allocation.

## The open decision (re-scope)

The global allocator (Phase 3's headline) would deliver **~2% SIZE, not 15%** — but
it still delivers large **CYCLE** wins (P1.3 already shipped strLen −54%, memcmp
−30%, etc.). So the size DoD, not the allocator, is what needs revisiting:

- **(A) Revise the SIZE DoD to the measured-reachable (~2–4%)** and justify any
  further Phase-3 allocator work on **cycles** (with a cycle measurement), not the
  ≥15% size band. Recommended.
- **(B) Declare the SIZE goal met-as-feasible** — the dead-code/dead-store/dead-LDA
  peephole stream (v0.16.0–v0.18.0) already took the reachable ~1–2% of static
  size; the residual is irreducible — and pivot the initiative to cycles +
  correctness, deferring the global allocator unless a cycle measurement justifies
  it over the existing within-BB allocator + DP-IMG promotion.
- **(C) Chase a non-allocator size lever** (extend pointer promotion / a smarter
  deref scheme to shrink the `_fcc_ptr` dance) — but the re-grounding flagged it
  largely irreducible; would need its own spike before committing.

**Recommendation: A (or B).** ≥15% SIZE is not in this codegen; revise the DoD to
the structural reality and gate any further allocator work on cycles.

## Reproduce

```
# toolchain branch feat/fcc2-p3-global-regalloc, fcc built:
#   for each tool: FCC_P3_STATS=1 build_userbin_fgx2_c <tool>  (stderr -> stats.tsv)
python3 toolchain/bench/p3stats.py --stats stats.tsv --code-bytes 103749
```

Infrastructure committed on the toolchain branch (`ir_p3_stats` + tests/p3stats/
+ bench/p3stats.py). The pass is gated off by default (byte-identical) and kept as
re-runnable instrumentation to track the curve as any future increment lands.

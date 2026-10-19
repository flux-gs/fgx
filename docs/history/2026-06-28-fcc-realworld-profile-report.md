# fcc real-world cycle profile — sed + fas (Phase 0)

> **Date:** 2026-06-28. Produced by the Phase-0 profiler (`tools/profile/`, plugin
> PC-sampler in `tools/mame_test/plugins/fgxdebug/init.lua`). Spec:
> `docs/history/plans/2026-06-28-fcc-realworld-speedup-profiler-design.md`.

## TL;DR — where real tools spend their cycles, and the lever

Two real, call-heavy FGX tools were PC-sampled under MAME on substantial
workloads. They land in **different** regimes:

| tool | dominant cost | next | implied fcc lever (spec §6) |
|---|---|---|---|
| **sed** (regex/substitute) | **user-body hot loops 58%** | kernel I/O 36% | **loop/region-scoped DP-IMG promotion** (codegen-only) |
| **fas** (assembler) | **`_fcc_mul16` ~58%** (16-bit software multiply) | user body 18% | **const-multiply strength-reduction + faster mul16** (codegen-only) |

**Both levers are codegen-only (low blast radius).** The profile *validates the
already-planned Tier-1 "const shift/mul lowering"* as high value (it directly
attacks fas's #1 cost) and motivates extending DP-IMG promotion from leaf
functions into **hot loops of call-heavy functions** (sed's #1 addressable cost,
currently blocked by the leaf-gate).

The before/after on sed also **empirically confirms the leaf-gate finding**: the
Track-2 B1c work gives sed **0% wall-clock change** and only −0.33% size, because
sed's hot regex loops live in call-heavy functions where promotion never fires.

## 1. Method

- A gated PC-sampler in the `fgxdebug` MAME plugin histograms the program
  counter once per frame (~60 Hz) **while the command runs** (armed after the
  scripted command fires, so boot/idle don't dilute the profile). It emits
  `{"samples":{"BB:OOOO":n,…},"total":N,"wall_s":Δ,"kernel_bank":K}`.
- `tools/profile/profile_report.py` parses the tool's merlin32 `-V` seg0 listing,
  maps each runtime `bank:offset` to its enclosing symbol (FGX2 relocates seg0 to
  a dynamic bank but **preserves the in-bank offset** — verified in
  `loader.s _LoadOneSegment`), and buckets into 5 categories
  (user_body / call_glue / prologue_epilogue / libc / kernel_io).
- **Kernel-bank exclusion (critical).** The kernel relocates to a dynamic bank
  whose in-bank offsets *collide* with the tool's seg0 offsets. On the sed run
  the kernel bank (0x7D) held 32% of samples; without excluding it, the kernel's
  I/O loop at offset 0x8358 was mis-attributed to sed's `ozunid_395` at the same
  offset. The plugin now emits `kernel_bank` and the report excludes it.

## 2. sed — CLEAN result

Workload: `sed -f /docs/heavy.sed /docs/big.txt > /root/profout` (5 substitution
/ address-range rules over a 15 KB generated file; output redirected so console
scroll doesn't pollute the profile). Exit via prompt-return (clean termination).

**Category roll-up (new fcc, HEAD):** 1358 samples, 22.6 s GS.

| category | % |
|---|---|
| user_body | 58.5% |
| kernel_io | 36.1% |
| libc | 4.0% |
| call_glue | 1.1% |
| prologue_epilogue | 0.3% |

**Top hot symbols** (user code unless noted): `_sed_L359` 14.7%, `_sed_L449`
14.1%, `ozunid_316` 7.7%, `_sed_L446` 6.0%, `_sed_L434` 3.5% — sed's regex match
+ substitute inner loops. libc share is the fcc 16-bit compare helpers
(`_fcc_ltu16` 2.3%, `_fcc_ne16`, `_fcc_geu16`). kernel_io (36%) is char-by-char
read/write through ProDOS.

**Reading:** sed is bound by its own hot loops (58%) inside call-heavy functions
(regex engine), plus a large I/O tail (36%). The hot loops are exactly what
DP-IMG promotion would accelerate — but they are **leaf-gated off** because the
enclosing functions make calls.

### sed before/after (old fcc `5692a76` → new fcc HEAD `8328828`)

| metric | old (v0.14.0-era) | new (HEAD, +B1c) | delta |
|---|---|---|---|
| binary size | 81559 B | 81289 B | **−0.33%** |
| workload wall-clock | exits @ frame **2076** | exits @ frame **2076** | **0%** |
| user_body share | 58.9% | 58.5% | ~0 |
| libc share | 4.8% | 4.0% | −0.8 pt |

Both builds complete the identical workload in the **same number of frames**
(prompt-exit at frame 2076) — a clean 0% wall-clock result. The Track-2 B1c
walk-deref promotion does not fire in sed's call-heavy regex path. **This is the
leaf-gate, measured.**

## 3. fas — PRELIMINARY signal (run not cleanly terminated; see caveats)

Workload: `fas /docs/big.s -o /root/bigout` (≈7.6 KB of varied 65816
instructions). fas is the compute-bound contrast to sed.

**Robust signal:** isolating fas's real code bank, **`_fcc_mul16` is ~58% of
fas's execution** (`c_strcmp` 4.6% = linear symbol-table name comparison;
`ozunid_191` 9.3% is the hot caller). fas is **fundamentally bottlenecked on the
fcc 16-bit software multiply**, with a secondary cost in linear symbol lookup.

**Why this is only preliminary (caveats, not silently dropped):**
1. **Exit detection failed for a verbose tool.** fas prints progress to the
   console, so the prompt-return heuristic never fired; both runs ran to the
   frame cap. The profile therefore mixes real fas work with shell idle (the
   idle lands in *other* banks, so it does not fabricate the mul16 hits, but it
   distorts the absolute category percentages).
2. **fas is multi-segment / >64 KB.** A second runtime bank (0x98) appeared as a
   thin scatter of single-hit offsets that the offset-only map spuriously
   resolved to fas symbols; the single-bank model the profiler assumes does not
   fully hold for fas.
3. The big workload did not finish assembling within the cap (a separate fas
   performance question, consistent with a mul16-heavy inner loop).

The mul16 dominance is trustworthy as a **direction**; the exact percentages are
not. A clean fas profile needs the Phase-0.5 items in §6.

## 4. Recommended lever

Read off the spec §6 decision table against both tools:

1. **Const-multiply strength-reduction + a faster `_fcc_mul16`** — *highest
   confidence, lowest blast radius.* fas spends ~58% in the 16-bit software
   multiply; many of those multiplies are by compile-time constants (struct
   sizes, table strides) that lower to shifts/adds. This is precisely the
   **Tier-1 "const shift/mul lowering"** already on the roadmap — the profile
   confirms it is high-value for compute-bound tools, not just micro-benches.
2. **Loop/region-scoped DP-IMG promotion** — *highest value for the regex/string
   tool class.* sed spends 58% in hot loops inside call-heavy functions that the
   current leaf-gate excludes. Promoting hot *loop bodies* (which are themselves
   call-free) within call-heavy functions would unlock those cycles. Bigger
   effort than (1); codegen-only.

Not indicated by this data: register-arg/ABI changes (call_glue + frame were
~1.4% for sed). Kernel I/O (36% of sed) is not fcc-addressable, though a buffered
libc read/write would cut it — a libc lever, separate from codegen.

## 5. Validation

- **Relocation correctness:** runtime `bank:offset` → seg0 offset confirmed
  (sed link bank 0B → runtime 6B, offsets preserved; samples resolve to coherent
  `_sed_L*` functions). Kernel-bank collision found and fixed (§1).
- **Determinism:** repeated identical sed runs are bit-identical (1358 samples,
  22.617 s) — MAME emulation is deterministic, so the spec §8.3 determinism check
  is satisfied exactly.
- **Old-fcc build provenance:** the silent-rebuild guard held (fcc `--version`
  asserted per build; old sed = 81559 B, new = 81289 B, distinct).
- The post-processor passed a 6-lens adversarial review (commit `4991e6f`);
  16/16 unit tests green.

## 6. Limitations & Phase-0.5 follow-ups

- **Clean fas profile** needs a non-prompt exit for verbose tools (an
  `exit_marker` the tool writes on completion, or output redirected away from the
  console) **and** multi-segment / >64 KB handling in the post-processor (key the
  map on `(bank,offset)`, or accept a `--tool-banks`/manifest CODE-bank list).
  Both are scoped, not blockers for the sed conclusion.
- Two tools is a start; the decision is anchored on the clean sed result plus the
  robust (if imprecise) fas direction. A third tool (e.g. grep) would strengthen
  the loop-promotion case.
- 60 Hz sampling resolves the top symbols/categories (the lever decision) but not
  fine intra-function structure; densification is a tuning knob, not required.

# fcc real-world speedup — Phase 0: real-tool profiler (design)

> **Status:** design approved 2026-06-28 (brainstorming). Terminal next step =
> writing-plans (implementation plan). This spec covers **Phase 0 only** (the
> profiler + the where-the-cycles-go report). Lever selection is an explicit
> **follow-up scoping** driven by Phase 0's data — it gets its own spec.

## 1. Goal

Build a **statistical profiler for fcc-compiled FGX tools** that attributes a
real tool's run-time cycles to a small set of categories, so the next fcc
optimization is chosen from **measured** real-world cost — not from
micro-benchmarks (which we have shown are unrepresentative). Deliver a profile
of `fas` and `sed` plus a short "where the cycles go" report and a recommended
lever.

**Non-goals (Phase 0):** implementing any optimization (loop-scoped promotion,
inlining, register args, callee-saved slots, etc.). Those are decided *after*
this profile and specced separately. No ABI changes here.

## 2. Background & diagnosis (measured this session, 2026-06-28)

The fcc optimization work to date (Tier-1 peephole/const-arith + the Track-2
register allocator and DP-IMG promotion) yields, on the fixed 13-bench leaf
micro-corpus: **geomean 1.19× (~16% fewer µs/call), up to 2.18× (strLen)**, at
**~0% binary-size change** (it is a cycle optimization, size-neutral by design).

But on **real shipping tools** the same work moves the needle far less:

| tool | v0.13.0→HEAD bytes | Track-2 (v0.14.0→HEAD) |
|---|---|---|
| sed | −0.70% | −0.33% |
| ed | −0.80% | −0.17% |
| grep | −1.38% | −0.70% |
| tr/more/man | −0.0–0.3% | ~0% |

**Root cause (verified):** the high-value promotion optimizations are gated to
**leaf, call-free functions** — `ir_promote_locals` bails on any function that
calls another function, because it cannot prove the callee won't clobber the
task DP page `$C0..$DF` that holds the `_fcc_img{k}` slots. The micro-benches
are leaf functions → promotion fires. Real tools are call-heavy → promotion
reaches only their leaf helpers → muted impact. The micro-corpus numbers are a
**per-leaf-function ceiling**, not a whole-tool figure.

So the real-world speedup question is: *where do call-heavy tools actually spend
their cycles, and which lever attacks that?* Phase 0 answers the first half.

## 3. Architecture overview

```
   workload (.s for fas / script+input for sed) on an FGX disk
                         │  (run under MAME via run.py)
                         ▼
   ┌──────────────────────────────────────────────┐
   │ fgxdebug MAME plugin  (+ NEW pc-sampler hook)  │  emits pc_samples.json
   │  - attach :maincpu, read cpu.state PC          │   { "PB:PC": count, ... }
   │  - sample on a fixed cadence; histogram        │   + load-bank map + run meta
   └──────────────────────────────────────────────┘
                         │
                         ▼
   ┌──────────────────────────────────────────────┐
   │ profile_report.py  (NEW host post-processor)   │  reads:
   │  - relocate runtime PB:PC → link-relative addr │   - pc_samples.json
   │  - map addr → symbol via seg0 listing          │   - build/userbin_<t>_seg0_Output.txt
   │  - bucket symbols into the 5 categories         │   - FGX2 link manifest (load map)
   └──────────────────────────────────────────────┘
                         │
                         ▼
            per-function + per-category profile  ──►  "where the cycles go" report
```

Two new artifacts: a **PC-sampler hook** in the existing `fgxdebug` plugin
(`tools/mame_test/plugins/fgxdebug/init.lua`), and a **host post-processor**
(`tools/profile/profile_report.py` — new). Everything else (MAME, run.py disk
boot, the seg0 listings, the FGX2 link map) already exists.

## 4. Components

### 4.1 PC-sampler hook (in `fgxdebug` init.lua)

The plugin already attaches to `:maincpu` (`manager.machine.devices[":maincpu"]`),
reads `cpu.state`, and writes JSON output. Add an **opt-in sampler** driven by a
new config key (`"pc_sample": { "enable": true, "out": "<path>", "cadence": ... }`):

- **Cadence (baseline):** a per-frame notifier (60 Hz) reading the program-bank
  + program-counter from `cpu.state` (the bank-aware full address, `PB:PC`),
  incrementing `hist[PB:PC]`. Per-frame is the low-risk baseline (~60
  samples/sec → a 30–60 s run gives 1.8–3.6 k samples — enough to rank the top
  functions/categories, which is all the lever decision needs).
- **Densification (if resolution is short):** escalate to an execution tap over
  the tool's code banks (`cpu:install_read_tap` / execution-tap equivalent) or
  a sub-frame timer. Treated as a tuning knob, not required for v1.
- **Output:** at the existing dump point, write `{ "samples": {"BB:OOOO": n, …},
  "total": N, "wall_s": emu.time-delta, "meta": {...} }` to the configured path.
- **Gating:** entirely behind the config flag → zero effect on existing
  cycle_markers / golden / oracle runs (mirrors how cycle_markers is gated).

### 4.2 Symbol-mapping + categorization post-processor (`tools/profile/profile_report.py`)

Pure host Python. Inputs: `pc_samples.json`, the tool's
`build/userbin_<name>_seg0_Output.txt` (merlin32 listing: address + label per
line), and the FGX2 link manifest / load map (for the runtime load bank(s)).

Steps:
1. **Parse the listing** → an ordered table of `(link_addr, symbol)` for every
   labelled location (function entry points and internal labels), plus the
   address ranges between consecutive labels.
2. **Relocate** each sampled `PB:PC` from its runtime bank back to the
   link-relative address using the load map (FGX2 relocates segments to
   loader-assigned banks at run time — the sampler sees runtime banks, the
   listing is link-relative). Samples whose bank is the kernel / libc / unknown
   are tagged accordingly rather than dropped.
3. **Attribute** each sample to the enclosing symbol (largest `link_addr ≤ addr`).
4. **Bucket** into the §5 categories and emit: a ranked per-symbol table (% of
   samples) and a per-category roll-up.

### 4.3 Workloads

- **fas**: assemble a large representative `.s` (compute-bound: lexer + symbol
  table + two-pass emit; the call-heavy real-program case). Input sized so the
  run is ~30–60 s of GS time for good sample density.
- **sed**: a complex multi-rule script (several `s///g`, address ranges) over a
  large generated text input (string/regex hot loops).
- Each workload is run twice — once with the **HEAD** tool binary and once with a
  **pre-optimization (v0.14.0-era)** tool binary built by swapping `toolchain/fcc`
  (the verified procedure from this session) — so we get a true **before/after
  whole-tool wall-clock** (`emu.time` delta from the sampler) as a side effect,
  alongside the profile.

### 4.4 Report

A short markdown report (committed under `docs/history/`): per-tool ranked
hot-symbol table, the 5-category roll-up, the before/after whole-tool wall-clock,
and a **recommended lever** read off the §6 decision table with its rationale.

## 5. Attribution categories

Every sample is rolled into exactly one of:

1. **User-function body** — the tool's own compiled C, per function (the meat).
2. **Call glue** — argument push sequences + `JSR/JSL/RTS/RTL` and the
   computed-RTS far-call trampoline.
3. **Prologue / epilogue** — `TSC/SEC/SBC/TCS` frame establish + teardown
   (identified by the per-function entry/exit ranges in the listing).
4. **libc** — `_fcc_*` runtime + ported libc (memcpy/malloc/printf/regex/…),
   identified by the `_fcc_`/libc symbol namespace.
5. **kernel / syscall / I-O** — samples in the kernel bank / syscall dispatch
   (un-addressable by fcc codegen → it caps the achievable speedup).

## 6. Decision framework (how the profile picks the lever)

| If cycles are dominated by… | indicated lever | blast radius |
|---|---|---|
| hot loop **bodies** in call-heavy functions (loop itself call-free) | **loop/region-scoped promotion** | codegen-only |
| hot loops calling **small leaf helpers** | **inlining** (kills glue + unlocks promotion) | codegen-only |
| **call glue + prologue/epilogue** | **register-arg passing / cheaper frame** | ABI |
| functions that **just-miss** promotion due to one call | **callee-saved DP-img slots** | ABI |
| **libc** internals (memcpy/malloc/regex) | promote/optimize libc | codegen-only |
| **kernel/syscall/I-O** | not fcc-addressable; documents the ceiling | n/a |

Phase 0 produces the data + a recommendation; the chosen lever is specced and
built in a follow-up.

## 7. Key implementation concerns / risks

- **FGX2 bank relocation (the main correctness risk).** The sampler sees runtime
  `bank:offset`; the listing is link-relative. The post-processor MUST relocate
  correctly using the load map, or every attribution is wrong. Mitigation: the
  plugin also dumps the tool's loaded base/bank(s) (it already dumps memory
  regions); validate the relocation by confirming a known symbol (e.g. the
  tool's `main`) lands where samples cluster at startup.
- **Sample density / statistical noise.** Per-frame (60 Hz) is coarse; size
  workloads to ≥30 s and report sample counts + only rank symbols above a
  support threshold. Densify (4.1) if the top-N is unstable across two runs.
- **Old-fcc tool build provenance.** The before/after build MUST verify the
  swapped `toolchain/fcc` version and guard against the silent-rebuild trap hit
  this session (`PROJECT_ROOT` reset by sourcing `build_common.sh` → it rebuilt
  HEAD fcc for "both" sides). Set `PROJECT_ROOT` *after* sourcing; assert
  `toolchain/fcc --version` matches the intended commit; fail loudly on a
  "Building fcc…" message.
- **libc/kernel attribution.** Samples outside the tool's banks must be tagged
  (libc vs kernel) not dropped, or the category roll-up understates I/O.
- **Representativeness.** Two tools is a start, not proof; the report states the
  workloads explicitly and avoids over-generalizing a single hot path.

## 8. Validation (how we know the profiler is correct)

1. **Relocation sanity:** a startup-clustered sample set maps to the tool's
   entry/`main` region; a known tight loop (e.g. sed's char scan) shows up as a
   top symbol.
2. **Cross-check vs cycle_markers:** wrap one hot function with the existing
   `emit.time()` markers; its marker-measured share should match its sampled
   share within statistical error (this is the §4.1→§4.2 ground truth).
3. **Determinism:** two runs of the same workload produce the same top-N symbols
   (above the support threshold) and category roll-up within noise.

## 9. Deliverables

- `tools/mame_test/plugins/fgxdebug/init.lua` — PC-sampler hook (gated).
- `tools/profile/profile_report.py` — relocate + map + categorize + report.
- A small fixture set: the fas `.s` workload and the sed script+input.
- A driver (extend `run.py` test JSON or a thin wrapper) that builds old/new
  tool binaries, runs both under MAME with sampling, and invokes the report.
- The committed profile report (fas + sed: hot-symbol tables, category roll-up,
  before/after wall-clock, recommended lever).

## 10. Out of scope (explicit)

Any codegen/ABI optimization; whole-program/LTO; a continuous/CI profiling
regime; profiling tools other than fas + sed (v1). These follow from Phase 0's
findings.

# vi startup optimization — plan

**Date:** 2026-07-20
**Goal:** make `vi` (elvis, a 363 KB 6-bank far-linked binary) start faster.
**Status:** Phase 0 (diagnosis) EXECUTED 2026-07-20 — results + time budget below.
**Branch:** `feat/libc-mvn-bulk-ops` (toolchain `44232ade` + fgx `18b46494` already
landed the Tier-1 copy fix; everything below Phase 0 is unbuilt and CONDITIONAL).

## Where we actually are (read this first)

- **DONE + committed:** libc `memcpy`/`memset` byte-loop → 16-bit word loop.
  **0.616 s → 0.340 s = 1.81×** (membench, cycle_markers). Correctness: membench
  byte-exact even/odd/tiny/zero + no-overrun; grep/sed/cat/curtest/libcshare green.
  **SOLID.**
- **`vi` start-to-paint = 6.045 s** emulated (deterministic). Trustworthy as a
  marker *delta*; its *labels* (DONE=paint, START=vi) are not yet verified.
- **RETRACTED:** "vi startup is 94 % disk-I/O-bound" was **wrong** — mis-resolved
  `7D:922F` (it's the post-`WAI` idle park, not the scheduler resume path), and the
  pc_sample window (12 s) was 2× the measurement window (6 s), so the dominant
  "idle" samples are the **post-paint keyboard wait**, sampled outside the load.
  The disk path is synchronous (no sleep), so a loading task can't idle-block.
  **We do not yet know where the 6 s goes.**

**Guiding principle: measure before optimizing. Everything in Phases 1–3 is gated
on Phase 0. Nothing marked "do anyway" — the earlier attribution error is exactly
what that instinct produces.** Emulated time ≠ real-hardware time (MAME doesn't
model SCSI latency), so device-latency conclusions are off the table under MAME.

## Phase 0 RESULTS (2026-07-20) — deterministic (0 variance across 3 runs each)

Method: three temp markers (Load_Binary entry / `@lb_fgx2_ok` return / elvis first
`ttyread`), paired cycle_markers runs in inject mode, paint-gated pc_sample, and a
`_kBlkReadCount` (`7D:E74C`) dump delta vs a `true` baseline. Markers reverted.

**Phase split (vi start-to-paint = 5.891 s this build):**
- **Load+reloc (inside Load_Binary): 3.920 s = 66 %**
- Userland (crt0 tail + elvis init + paint): 1.971 s = 34 %

**Region attribution (paint-gated pc_sample, window 6.3 s ≈ startup):**
- **SmartPort/SCSI firmware block reads (`00:C8xx` — CONFIRMED via block.s:98,
  the `$Cn00+[$CnFF]+3` firmware entry that switches in the `$C800` ROM): ~30 % ≈ 1.9 s**
- **Kernel loader / FS-tree / staging-copy / reloc (`7D`): ~46 % ≈ 2.9 s**
- **Userland elvis + libc (`7B`/`7A`/…): ~24 % ≈ 1.5 s** (the `7B:A22x` libc cluster)

**Block count: 544 device block reads for vi startup** (`_kBlkReadCount` 459→1003;
image ≈726 blocks, so the cache serves ~180). Every read = one synchronous firmware
call + kernel staging. ⇒ the load is **per-block software+firmware overhead**, NOT
idle-wait (retracted) and NOT device latency (unmodeled).

**TIME BUDGET → selected levers (spend proportionally):**

| Slice | Time | Lever | Gate |
|---|---|---|---|
| Firmware read leg | ~1.9 s | multi-block / batched SmartPort reads | firmware multi-block capability (0.6 — UNVERIFIED) |
| Kernel staging/FS/reloc | ~2.0 s | collapse per-block staging copy chain (fw buf→kernel→cache→user); block-cache readahead. Applies to cache-HIT blocks too (still copy to user bank). Separate reloc-vs-stage within this still TODO. | — |
| Userland libc (`7B`) | ~1.1–1.5 s | **Phase 1 JUSTIFIED** (libc ≥ ~24 % of window): memset unrolled-STA + memcpy long-indexed | multibank fixture for memset |
| Userland elvis init | remainder | `TERMCAP` env / trimmed termcap / lazy init (FGX-owned seams only) | — |

**Still owed (cheap Phase-0 refinement):** Run 2 (warm re-exec → Phase 3 ceiling;
small-binary control → fixed-vs-proportional spawn cost); separate reloc from
staging inside the `7D` 46 % (the MID-gated split is blocked — see below).

## Phase 0 VERIFICATION (Fable, 2026-07-20) — corrections that change the levers

The measurement *architecture* passed adversarial review (markers bracket what
they claim; reloc is inside Load_Binary; paint-gating killed the old idle-park
artifact; determinism real; "not idle-wait / not device-latency" survives). But
three corrections land, two of them lever-changing:

1. **The `7B` 18 % is NOT memcpy/memset — it's div/mod + long helpers.** seg2.lst:
   `JSR _fcc_long_from_int` targets `$A22D`, with `_fcc_modu16`'s 16-iteration
   shift-subtract loop just above (`A223/A226/A229`). This is paint-path math
   (screen-address `/` and `%`, `tgoto` `%d`, printf digits) — **not copies.**
   ⇒ **Phase 1 re-aims: faster `_fcc_modu16`/div16 + long-conversion helpers, or
   fewer div calls in the paint path. The memset/memcpy justification is DROPPED**
   (the asm memcpy is already MVN; those routines are nowhere near `A2xx`).
2. **Lever (a) batch firmware reads is INFEASIBLE.** The SmartPort READ path is
   single-block (block.s: param count `$03` = unit/buf/blocknum; `SP_READ_BLOCK`,
   one 512 B block, no count). Batching would need a native SCSI driver bypassing
   SmartPort — out of scope. The ~1.9 s firmware leg is **fixed at 544 single-block
   calls** unless block *count* is reduced (compression / warm cache), not batched.
3. **"544 device reads" is 544 block *requests*.** `_kBlkReadCount` counts at
   Blk_Read entry, above the cache. Device reads = requests − `BCS_HitCount`. For a
   COLD sequential load the cache can't hit (32-slot pool), so requests ≈ device
   reads here; and `544 < 726` is the **T5-B shared-libc skip** (elvis's LIBC
   segment matches jsh's registered pile → loader `Fs_Lseek`s past ~128 blocks),
   not cache hits. A bigger block cache is NOT a lever (cold first-touch can't
   cache).

Also noted: the `7D` 46 % and `7B` 18 % are full-window (mix load-phase kernel work
+ userland-phase syscalls + a ~0.44 s injection-pacing HEAD; `7B` also carries
jsh's libc since it shares the pile bank). The clean load-phase split needs a
load-phase-gated histogram, but MID-gating on `$025002` fails (it's written by
every FGX2 load, so it's already set from boot when the poll starts). A per-frame
timestamped-PC dump (small plugin change) would fix it; deferred.

## REVISED lever set (post-verification) — what's actually worth building

| Lever | Attacks | Feasible? | Shape |
|---|---|---|---|
| **B: collapse per-block staging** | ~2.0 s kernel leg | **YES, high-confidence** | stream device→dest bank, skip cache-insert for sequential LOAD reads (loads pollute the cache anyway); removes ≥1 MVN + cache work per block ×544. Kernel FS/block change (hazard-class; one change, closed-loop). |
| **Phase 3: sticky text cache (warm)** | whole 3.9 s load on RE-exec | YES, biggest ceiling | 0 on first launch; bank-affinity re-hand; inode+mtime invalidation; 6-of-22-bank pressure. |
| **Phase 1: faster div16/mod16 + long helpers** | ~1 s paint-path math | YES, contained | toolchain `_fcc_modu16`/`_fcc_long_from_int`; helps all div/mod system-wide. |
| ~~A: batch firmware reads~~ | ~1.9 s firmware leg | **NO** (single-block SmartPort) | would need a native SCSI driver — out of scope. |
| Compression | block *count* | maybe | LZ decode ~50–90 KB/s vs read cost — measure first. |

Recommended build order: **B (biggest feasible cold-launch win)** → Phase 1
(contained, correctly-targeted) → Phase 3 (warm re-exec). Each gated by the tiered
test cadence + closed-loop; FS/block change lands one-at-a-time.

## Phase 0 — Diagnosis (GATE). Collapsed to 3 runs off ONE kernel build.

The harness markers are per-address write-taps (one START/DONE pair per run), so
naive phase-segmenting would be 3+ instrumented builds. Instead: write **distinct
byte values** to a single tapped address at each phase boundary and have the plugin
record (value, emu.time) per write — one run yields all boundaries. If the plugin
only latches first/last write, add multi-write capture (~30-line plugin tweak; pays
for itself). Boundaries to stamp: **spawn-entry** (process.s, around the `JSR
Load_Binary` at process.s:211) · **Load_Binary success-return** (loader.s ~393,
the single `PLP/SEC/RTS` success exit) · **first paint** (elvis first `ttyread`).

- **Run 0 — baseline variance.** The unmodified 6.045 s measurement ×3. If
  run-to-run noise is ±300 ms, we do not attribute sub-half-second slices to
  anything. (Cheap; do first.)
- **Run 1 — the decisive run (one kernel build).** Multi-value phase markers +
  pc_sample **gated to [spawn-entry, paint]** + a tiny in-guest `SYS_KSTAT` probe
  in the input script reading `_kBlkReadCount` / `BCS_HitCount` before+after +
  `bpset` count on `Load_Binary` entries + a screenshot at the paint marker. This
  ONE run yields, together:
  - the **phase budget** (ms in: kernel spawn plumbing · load+reloc · exec→paint);
  - **per-phase hot-spot attribution** by PC region — firmware-ROM banks vs
    staging MVNs vs FS-tree code vs the reloc loop vs elvis user banks (this
    replaces the cut "bracket the Fs_ReadN loop" run, which would have measured the
    envelope ≈ whole load, not time-in-loop);
  - **true block counts + cache-hit rate** (real device-op count, tree
    index-block amplification) from the KSTAT deltas;
  - **label verification** — DONE actually = painted screen; START = vi and not a
    `$PATH`-probe/pile-load. (Spawn stages the path then calls `Load_Binary` once
    — syscall.s:2256 — so probes are likely userland stat/open; the bpset count is
    cheap insurance.)
- **Run 2 — warm re-exec + small-binary control (same build, same boot).** Run
  `vi`, `:q`, run `vi` again; and spawn-to-paint an existing tiny FGX2 binary.
  Yields: **cold-vs-warm split** and block-cache efficacy (a *free preview of
  Phase 3's entire ceiling*), and **fixed per-spawn cost vs size-proportional
  cost** (separates kernel spawn plumbing from the load itself — the "remainder"
  is NOT purely elvis init; it also holds argv/envp staging + TCB + fd actions).

**Optional, only if Run 1 leaves ambiguity:** RAM-disk A/B (elvis on `DEV_CLASS_RAM`
vs SmartPort) — but under MAME this can only isolate the *firmware-call leg* from
everything else (no real device latency modeled), which Run 1's PC attribution
already gives; expect "barely moves." Firmware multi-block capability (0.6) — a
gs-mcp / firmware-doc lookup — only if the firmware leg is a large slice.

**Phase 0 output = a TIME BUDGET (ms per category), not a single "branch."**
Categories can co-dominate; spend proportionally. Category → lever map:

| Category (from Run 1/2) | Lever |
|---|---|
| Kernel spawn plumbing (fixed, from small-binary control) | spawn-path code, not termcap |
| Load+reloc, **device/firmware-leg** heavy | fewer/larger firmware reads *iff* 0.6 says multi-block possible |
| Load+reloc, **staging-MVN/FS-tree CPU** heavy (incl. cache-HIT path, which still copies to the user bank) | collapse the firmware→kernel→cache→user copy chain; block-cache readahead |
| Reloc loop heavy | sorted/delta reloc offsets; per-(segment,bank) precomputed patch byte |
| exec→paint (true elvis init: `tgetent`, screen init, `/etc/hostname`) | FGX-owned seams only — `TERMCAP` env / trimmed termcap, `unix.c`/curses seam, lazy init; **never** edit vendored `main.c` |

## Phase 1 — Copy primitives (CONDITIONAL on Run 1 gated profile)

Gate: the **gated** profile shows copy primitives ≥ ~10 % of the window. (The prior
"memset is the top hot spot" claim came from the *contaminated* dataset — do not
re-optimize off it.)
- **1.1 memset → DBR-pinned fixed-displacement unrolled STA** (~3.9 cyc/byte).
  Not risk-free: DBR-pin must re-pin at bank crossings (`offset+len` wraps $FFFF) —
  the multibank single-bank-invisible bug class (~68 sites on record). Needs a
  **multibank fixture**, not just goldens-green.
- **1.2 memcpy → unrolled `LDAL/STAL` long-indexed** (~7 cyc/byte). Trampoline
  DROPPED (equal speed, no SMC, trivially safe).

## Phase 2 — Loader (CONDITIONAL; spend per the time budget, not a single branch)

Levers per the table above. A (firmware read batching) and B (collapse staging
CPU) are two levers on the same per-block cost — the pc_sample per-block breakdown
picks the mix, they are not exclusive. Note the cache-**hit** path still copies to
the user bank, so a high hit rate does not mean the load is free.

## Phase 3 — Sticky relocated-text cache (CONDITIONAL — NOT diagnosis-independent)

Cache relocated code banks by inode+mtime; MM bank-affinity re-hand → warm re-exec
skips disk+reloc. **Gate on BOTH:** load+reloc is a large slice (Run 1) AND Run 2
shows that slice is actually recoverable warm (if the block cache already absorbs
most of it, Phase 3's marginal win is only reloc+staging, which B/D fix more cheaply
for *all* binaries). Costs the most and carries real risk: inode+mtime invalidation
correctness, and bank pressure — elvis is 6 of 22 user banks
(`BANK_USER_FIRST $0A..$1F`), so pinning it is ~27 % of user RAM held for one binary.
Saves **nothing on first launch** — which is likely what "make vi start faster"
means, so weigh accordingly.

## Correctness, testing, release discipline

- Copy changes are **toolchain-first** (fix libc → regen `libc_c.s` → regen goldens
  → gates → release toolchain → re-pin FGX). membench is the perf+correctness
  fixture; memset unrolled-STA additionally needs a multibank fixture.
- Loader/kernel/FS changes: tiered cadence (representative mame tests per change,
  full gate before land); FS/block is a known concurrency-hazard class — one change
  at a time, closed-loop.
- All Phase-0 markers/probes are **temporary** (revert before land).
- Never push feat branches; land via merge→main→`release.sh`; never self-merge.

## Superseded / dropped

- "vi startup is disk-I/O-bound" — RETRACTED (bad attribution).
- memcpy stack MVN-trampoline — DROPPED (unrolled long-indexed is equal + safe).
- "726 single-block reads = 5.7 s" — UNVERIFIED pending Run 1 KSTAT counts.
- Phase 1 / Phase 3 "do regardless" — CHANGED to conditional (gated on Phase 0).
- "device vs software via ramdisk A/B" as a primary step — DEMOTED (MAME models no
  device latency; Run 1 PC attribution answers it).

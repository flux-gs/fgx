# P3-5 = T3 (FGX3 binary format) — Stage-0 inventory + scope finding

**Branches:** `feat/p35-fgx3` in both repos, off the held P3-4 heads
(toolchain `e71dd3b2` / FGX `a6e7f6c0`). RELEASE HOLD in force.
**Date:** 2026-07-09. **Status:** Stage 0 done → **scope decision gates on the maintainer.**

## TL;DR

The Stage-0 inventory (git-verified) shows a from-scratch **FGX3 binary
container is not warranted** — and that call stands. But the first-pass reframe
to "ABI-stamp-only" was **too aggressive** (Fable design review, 2026-07-09,
below): it collapsed §T3's four bullets into the one that's easiest and dropped
the **gates and contracts** that are the actual point of the item. Corrected
scope: **no new magic, but P3-5 delivers the two mode gates (load-time byte +
link-time per-TU Layer2Gate), closes the fail-open reloc transport, funnels the
fcc reloc-emission accretion, and records a text-sharing decision with numbers.**
See "Corrected scope" below. Two irreversible wire decisions gate on the maintainer.

## What actually exists today (FGX2 at the P3-4 heads)

- **`fgx_ld.py` is a manifest-driven post-linker**, not a structured-object
  linker. It stitches pre-assembled headerless segment binaries + Merlin32 `-V`
  listings into an FGX2 image (header + segtab + concat data + reloc table).
  The "object model" *is* the FGX2 Merlin-macro set that fcc/hand-asm emit and
  `scan_listing` buckets.
- **Loader** (`include/loader.s`, `src/kernel/loader.s`) dispatches FGX1/FGX2 by
  magic and applies relocs **in-place**, streamed in 64-entry batches, into each
  process's own banks. No FGX3 magic exists anywhere in the tree.

## §T3 bullet-by-bullet vs. reality

| §T3 item | Status | Evidence |
|---|---|---|
| Typed relocs *by construction* (end `FGX2_LONG_PTR` accretion) | **grade INVERTED — transport is fail-open** | Macro set + `d1_check` exist, but `d1_check` (fgx_ld.py:140–196) validates relocs that *exist*; a silently-skipped listing row emits **no** reloc and leaves the `$00`/`$0000` placeholder — the documented `g_op_table`-at-`$0000` bug, memorialized in the parser (fgx_ld.py:222–226). The fragile macro-scan-of-`-V`-listing transport (`_parse_macro_row`) **is** the thing "by construction" exists to kill. The 33 `FGX2_LONG_PTR` + 11 `FGX2_FARCALL` + 9 `FGX2_EXPORT` scattered emit sites in fcc are the doc's central "per-site discipline vs by construction" disease (redesign:26–28), not a cosmetic refactor. **In scope.** |
| **D1 link-time bank gate (reloc drift)** | **✅ DONE** | `d1_check` (fgx_ld.py:140–196): $00-placeholder, JSL-shape + CODE-target, `CALLEE_ENTER` prologue + `n_data`, `LONG_PTR` pad, double-patch. Closes the reloc-*drift* case (reloc exists, wrong addr); the reloc-*absence* case is still open (row above). |
| ABI/mode stamp — **TWO gates** (mixing = link **and** load error) | **❌ missing; only load-half was inventoried** | redesign:329–331 specifies a *per-object* stamp so **mixing is a link error** (llvm816 Layer2Gate; llvm-mos.md:27–31 calls it "the cheapest structural fix"). First pass mapped this to a loader-checked header byte only and dropped the **link-time per-TU gate** that catches a stale pre-flip `.s`/listing mixed into a post-flip link — exactly the "make-from-src/cc silently stale" heisenbug class. Both halves are P3-5 work. |
| **Stack-size manifest field** | **✅ DONE** | FGX2 header byte 14 (`STACK_HINT_OFF`) fed by `stack_measure.stack_pages` from the fcc frame call-graph. Landed P3-3. |
| Dedup JML trampolines + one dispatch primitive | **❌ (optimization, not needed)** | Today `FGX2_FARCALL` does per-site global resolution and works. fcc-opt is already "COMPLETE-AT-FRONTIER" (≥15% size band proven unreachable); a trampoline-dedup pass needs measurement to justify and does **not** need a container change. |
| Per-task reloc tables / **text-sharing** | **❌ (open + blocked)** | Loader relocs in-place; no refcount/shared-text. Part V flags the cost as an **open** question to decide on **Phase-0 profiler data — which does not exist** (only fcc codegen-speed profiles exist). No current multi-instance consumer (nobody runs N copies of elvis). Textbook YAGNI + measurement-blocked. |
| Dead-strip / emit-once as linker properties | **overlaps Phase 1** | This is T5-A (shared-libc emit-once), a *different* phase. `LIBC_EXPORT` twins are already partially wired in `fcc_libc_shims.s`. Not P3-5's lane. |
| FGX1 retirement | **gated on the maintainer** | Deleting FGX1 emit/loader support is a named STOP-and-ask point. |

## Why the scope shrank (not laziness — the inventory the prompt asked for)

The redesign doc's T3 list was written 2026-07-05, **before** P3-3 (stack field)
and P3-4 (ABI v2 + the D1 gate context) folded the format-relevant pieces into
FGX2. Phase 3 was framed as one coordinated flag-day (T1+T4+T6+T3 together); in
practice, under the hold, T1/T4/T6 landed incrementally and **carried T3's
format pieces with them**. What remains is the residue above.

## Fable design review (2026-07-09) — verdict: PARTIALLY CORRECT

"Don't build a container" is right; "ABI-stamp-only" is wrong — it kept the one
byte and dropped the two gates that are §T3's point. Misses found:

1. **Mode gate is two gates, not one** — load-time byte (had) + **link-time
   per-TU** `FGX2_MODE` equality check (dropped). Zero mode machinery exists in
   `toolchain/src/ld/`, `toolchain/src/cc/`, or either loader. Catches the
   silently-stale-object class the ledger already records.
2. **Reloc transport is fail-open** — `d1_check` can't see a skipped row; the
   `$00`/`$0000` placeholder survives to the image. Closures: per-TU
   reloc-count cross-check (fcc knows how many FGX2_* it emitted → trailer macro
   → fgx_ld dies if scanned ≠ declared) + **D1b** orphan-placeholder scan
   (post-resolution, flag unclaimed `JSL $000000` / `$00000000` LONG_PTR images).
3. **Accretion = the bug class** — every historical reloc-shape bug (N-D array
   PHK/PHB, struct-array fn-ptr field drift, `char *field=&global`) was an
   accretion miss; the fix is one type-keyed reloc-emission funnel in fcc, the
   compiler half of "by construction." Phase-2's one-call-emitter makes it
   tractable.
4. **Text-sharing "no consumer" is wrong** — plan wants measure-then-decide at
   the flag day (redesign:491–493, 507, 546–548); the cooperative-multitasking
   push (ROADMAP:33–58) makes multi-process imminent. P3-5 owes the cheap
   bank-pressure measurement + a *written* yes/no with numbers (very plausibly
   "no — T5-A shared libc covers realistic mixes"), not a shrug.

Confirmed-correct calls: no new magic; text-sharing *implementation* YAGNI now;
trampoline-dedup is size-only (P3-2 already retired the 3-layer dispatch —
`emit_call_indirect` at emit.c:1858–1894 is one emitter); dead-strip → T5-A lane.
One honest caveat on stamp-vs-magic: stamp-only is **asymmetric** — a new kernel
rejects an old binary, but an **old kernel silently mis-runs a new binary**
(old loaders never read bytes 13/15). Acceptable under the one-image
release-train discipline, but it's the maintainer's call.

## Corrected P3-5 scope — increment ladder (cheapest-reversible first)

1. **ABI/mode stamp, both gates.** Header byte (13 or 15) = `abi_version`;
   `fgx_ld` stamps, loader rejects mismatch. **Plus** per-TU `FGX2_MODE <word>`
   macro (fcc + hand-asm) + `scan_listing` collect + `fgx_ld` cross-listing
   equality gate (link error on mixed mode). Wire commitments → the maintainer.
2. **Close the fail-open transport** — per-TU reloc-count cross-check + D1b
   orphan-placeholder scan. Pure link-time, zero wire/runtime change.
3. **One reloc-emission funnel in fcc** — collapse the ~53 scattered `FGX2_*`
   emit sites to one type-keyed emitter. Compiler-internal, no wire change;
   gated by the multibank oracle + goldens.
4. **Text-sharing measurement + written decision** (NOT implementation) —
   bank-pressure numbers for the multitasking process mixes; record yes/no with
   data. Only a "yes" surfaces a reloc-record wire question to the maintainer.
5. **Explicitly out:** new container/magic, trampoline-dedup (size, measure-
   first), text-sharing implementation, emit-once (T5-A / Phase 1),
   FGX1 retirement (the maintainer-gated).

## Execution status (2026-07-09, the maintainer green-lit "FGX3 = stamped FGX2")

The maintainer approved the revised framing: FGX3 = new magic, **byte-identical FGX2
layout**, byte 13 = `abi_version` — symmetric rejection for ~10 loader lines,
no new container design. Ladder in flight on `feat/p35-fgx3`:

- **[x] I1 — FGX3 magic + ABI stamp** (tc `417b0e0a` / FGX `9212abc1`).
  `fgx_ld` manifest `"format": "FGX2"|"FGX3"` (FGX2 output byte-identical;
  no abi-override option on purpose — a linker that can mint stale stamps
  defeats the gate). Loader: `@lb_fgx3` accepts 'FGX3', validates byte 13
  == `FGX_ABI_CURRENT`=2 via 16-bit read at +12 masked `#$FF00`, shares
  `_LoadFGX2` wholesale; mismatch → ENOEXEC. `build_userbin_fgx2_c` gained a
  format arg; fgx3probe = first FGX3 binary. **Gates:** goldens 381/381 +
  stack_check 0; build.sh disk OK (kernel 45531 B); MAME fgx3probe GREEN,
  fgx3reject GREEN (stale-stamp fixture `bin/fgx3bad.bin` minted by build.sh,
  byte-13=1, loader ENOEXECs it), fgx3reject_check.py RED-proven (rc=1
  against the PASS dump), abiprobe GREEN (P3-4 oracle intact with the loader
  change).
- **[x] I2 — link-time FGX2_MODE gate** (tc `e3d5f3bf` / FGX `a62a6f2c`).
  `FGX2_MODE` 0-byte macro
  in BOTH macros.s copies; fcc stamps `FGX2_MODE 2` as line 1 of code .s
  (direct to dst, post-peephole) + data .s header; `FGX_MODE_CURRENT` in
  main.c. fgx_ld: `scan_listing` collects; gate = every stamp == 
  `FGX_ABI_CURRENT`, and FGX3 output REQUIRES a listing + ≥1 stamp per
  segment (fail-closed; byte 13 derived from verified agreement). Goldens
  REGENed (381/381, ~760 .s/.data.s churn, **zero .bin churn** — stamp is
  0-byte). run_runtime 381/381, 0 regressions. **RED-proven ×2**: doctored
  stamp value 1 dies naming the value; stripped stamps die "found none".
- **[x] WHOLESALE FLIP** (FGX `86ea8d87`) — `build_userbin_fgx2_c` defaults
  to FGX3: **76 C binaries FGX3 + 40 FGX1 hand-asm**; jsh itself is FGX3, so
  every MAME test now boots through the FGX3 loader path. Loader keeps
  accepting FGX2 (elvis manifests, staged fixtures, ad-hoc WIP bins — 14 on
  disk). heaptest MAME failure = pre-existing orphan (untracked json, binary
  never built by build.sh; screen shows "not found"), not a flip regression.

**P3-5 LADDER COMPLETE 2026-07-09** — I1 ✅ I2 ✅ I4 ✅ I3 ✅ I5 ✅(decision:
NO) + flip ✅. Heads at close: toolchain `f2213b7d` / FGX `86ea8d87`, both
`feat/p35-fgx3`, RELEASE HOLD intact, submodule unbumped. T3 is the last
Phase-3 item → **Phase 3 (T1+T4+T6+T3) is code-complete under the hold**;
the release train (P3-4 first, then P3-5) gates on the maintainer.
- LESSON (re-learned): `run_runtime.py` runs `./build.sh disk` INTERNALLY —
  it rebuilds the FGX world (including tools/*-fgx2 dirs) with the current
  fcc mid-run. Never doctor those dirs or start builds while it runs.
- **[x] I4 — one type-keyed reloc-emission funnel** (tc `5698952f`). All 17
  real emission statements (the "53" grep count included comments) collapsed
  into `emit_mac_longptr` / `emit_mac_farcall` / `emit_mac_export` in emit.c;
  printf-style name args; line positioning stays at call sites. **Gate:
  goldens 381/381 WITHOUT REGEN — byte-identical output, pure refactor.**
- **[x] I3 — fail-open transport closed** (tc `f2213b7d` / FGX `d4eac827`;
  executed AFTER I4 because the funnel makes the data-side counter one line).
  (1) Per-TU `FGX2_RELOC_COUNT` trailer in both fcc outputs — code side
  counted from the post-peephole ground truth, data side from the funnel
  counter; fgx_ld attributes recognized rows per source file (listing file
  column) and dies on declared != recognized both directions; FGX3 links
  require every MODE-stamped file to declare. (2) **D1b orphan-JSL scan** —
  unclaimed `JSL $000000` images in CODE segs fail the link. **Gates:**
  goldens REGENed 381/381 ×2 (zero .bin churn); run_runtime 381/381 = also
  the D1b false-positive sweep over every fixture + all userland relinks
  (**zero false hits — D1b ships as a hard error**); MAME battery GREEN.
  **RED-proofs ×3** (scratch fixture): deleted EXPORT row → "declares 2 but
  1 recognized"; stripped COUNT rows under FGX3 → stale-.s error; injected
  `22 00 00 00` → D1b fires.

## I5 — text-sharing measurement + decision (2026-07-09): **NO, with triggers**

Measured (bank_pressure.py over the built bin/, FGX2/3 headers + segtab):
130 binaries = 40 FGX1 (1 bank) + 88 FGX2 (2 banks) + probes; jsh=2 banks
(67.4KB used), ed=2 (43.9KB), sed=2 (82.7KB across both), elvis=6 (audit:
5 code + 1 data, ~414KB pinned). User pool = 22 banks ($0A–$1F, 1.375MB).

**The multitasking push's own payoff mix** (ROADMAP: shell + TCP/HTTP server
+ background ntpplay + editor + pipeline tools): jsh(2) + elvis(6) +
echod(2) + ntpplay(1) + 2×tool(4) = **15 of 22 banks — fits with 7 spare.**
Pressure onset needs ≥3 concurrent elvis-class binaries (3×6+2 = 20/22) —
not a target workload. No target workload runs N≥2 instances of the same
binary (job-control suspend of a second editor is the only plausible case:
2×elvis would save 5 banks, 2×jsh saves 1).

**Cost side:** per-task reloc tables ≈ 4B × reloc_count per instance
(elvis: 1728 relocs ≈ 6.9KB/task) + an indirection hop on EVERY cross-bank
JSL at runtime + the loader/ABI break (in-code patching → table dispatch).
Below 2 concurrent same-binary instances it costs memory and saves none.

**The compatible levers land first anyway** (audit fgx-banking.md fix order):
T5-A per-binary shared-libc segment (~45KB/elvis-class binary, toolchain-
only), T5-B kernel load-once+refcount libc (Phase 4), and T8 sub-bank
co-location (which is what actually relieves the 2-bank-per-15KB-tool
granularity waste — text-sharing wouldn't touch it). All deliver the same
pool relief without the ABI break.

**Decision: do NOT build per-task reloc tables / text-sharing now.**
Revisit triggers (any one): a real workload with ≥2 concurrent instances of
a ≥3-bank binary; field Bank_Alloc ENOMEM under the multitasking push;
NPROC raised past 8; or T5-B landing makes the marginal cost of step-3
sharing small enough to ride along.

## Irreversible wire decisions — the maintainer only

- **(a) Stamp mechanics:** which reserved byte (13 or 15) carries `abi_version`,
  and whether the mode word also travels in the binary header or stays
  link-only (link-only is lazier and sufficient for the stale-object gate).
- **(b) Stamp-vs-magic asymmetry:** accept that an old kernel won't cleanly
  reject a v2 binary (stamp-only, recommended under the release-train), or spend
  a new `FGX3` magic to get symmetric ENOEXEC rejection.

Increments **2 and 3 need neither decision and are pure win** — they can start
immediately. Increment 1 waits on (a)/(b).

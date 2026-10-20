# Fast program launch — dormant-image / restart architecture

**Date:** 2026-07-20
**Status:** DRAFT for Fable review, then implement.
**Origin:** the vi-startup investigation (`2026-07-20-vi-startup-optimization.md`).
Root finding: FGX cold-loads every binary off disk on every launch; GNO/GS-OS is
near-instant because it **re-attaches a dormant, already-relocated image** on
re-exec (`kern/gno/sys.c` `KERNexecve`: `GetUserID2(path)` → `Restart(newID)`,
falling back to `InitialLoad2`; dormancy kept via `UserShutDown(userID,$4000)`).
The win is *not loading*, not a faster loader.

**Decisions (the maintainer, 2026-07-20):** native SCSI driver TABLED (future). B is
"good enough" for Track 1 (SmartPort multi-block is empirically dead — this card
rejects the `READ` call; tested). The real leverage is Tracks 2–3.

## Findings log — measured & durable (2026-07-20)

Instrumentation: temp cycle-markers at Load_Binary entry / `@lb_fgx2_ok` return /
elvis first-`ttyread`, cycle_markers + `FGX_MAME_PRIMARY=inject`. All deterministic.

**Baseline (elvis / vi, 363 KB, 6 banks):** start-to-paint = **5.89 s** emulated
(~7 MHz MAME). Split: **load+reloc 3.92 s (66 %)** / userland 1.97 s (34 %).
Load-phase region attribution (paint-gated pc_sample, twice Fable-verified):
SmartPort firmware block reads (`00:C8xx`) ~30 %, kernel loader/FS/staging (`7D`)
~46 %, userland libc/elvis (`7B`) ~24 %. Block count: **544 device reads** for the
whole startup (cold; the shared-libc pile skip explains 544 < 726).

**Governing law:** startup is **load-size-proportional** — code-growth optimizations
BACKFIRE. Proven: an unrolled-STA memset was faster per-byte but made vi **+0.16 s
slower** by bloating the shared libc pile (more blocks to load). REJECTED.

**Committed win:** word-loop `memcpy`/`memset` (toolchain 44232ade, **1.81×**,
size-neutral, broad). Independent of vi startup.

**Dead ends (durable — don't re-attempt):**
- **SmartPort multi-block READ** — the Apple II SCSI card REJECTS the `READ`
  ($08) call on its block device (tested both block-# and byte-offset address
  forms; boot halts; READBLOCK control boots fine). Only single-block READBLOCK
  works. Multi-block would need a native SCSI driver (tabled). Spec (Firmware Ref
  p150) warns block devices reject the character-device call family — confirmed.
- **B1 (skip the F2 cache-populate for load reads)** — UNSAFE. Skipping
  `_BlkCache_WrOk` during a program load HALTS boot (init's load). Isolated: the
  halt is the block.s guard itself, not the flag placement (tested in memmap
  [region full → overflow] AND kernel-DP $B6 [zeroed at init] — both halt).
  `_BlkCache_WrOk` reads as pure pool-populate but is load-bearing — almost
  certainly a DBR/state side-effect the post-read `STA _fsTmp1` depends on. So the
  "cache is pure pollution for loads" premise (mine and Fable's) is WRONG; the
  cache-populate is NOT skippable. A real "B" needs the more invasive path (reduce
  the `_fsDataBuf → user` copies / read closer to dest) — DEFERRED.

**Net:** the cold-path levers have largely closed (SmartPort dead, B1 dead, B2
deferred/invasive). Per GNO and Fable, **the win is Tracks 2–3 (not-loading)**,
which are independent of any cold-load optimization.

Measurement harness that survives: `tools/mame_test` cycle_markers +
`FGX_MAME_PRIMARY=inject`; membench (`src/userland/membench/`) for libc primitives.
NB campaign markers used absolute `$025000/$025002` — they COLLIDE with membench's
fbench markers; use distinct addresses if measuring both at once.

## Track 1 — Minimize the COLD load (B: collapse per-block staging)

Every load block currently costs ~3 MVNs + an FS-tree walk: firmware→`BLK_STAGE`
→ cache-pool populate → `_fsDataBuf` → user bank. The pool populate is pure
pollution for a sequential read-once load.
- **B1:** a `_blkLoadBypass` flag (set by spawn around `Load_Binary`) so `Blk_Read`
  skips `_BlkCache_WrOk` on read-miss during a load. Size-neutral, correctness
  intact (data still delivered at `$00:BLK_STAGE`). **Prereq: the earlier B1
  attempt boot-halted** — suspected the `memmap.s` Dum-section insertion; isolate
  across separate builds (place the flag without perturbing kernel layout).
- **B2 (stretch):** read closer to the destination bank (fewer intermediate MVNs).
- Cold-load floor for elvis stays ~1.9 s (544 single-block firmware calls,
  unbatchable without the tabled native SCSI driver). B recovers the ~2.0 s
  staging leg → cold load 3.92 s → ~2 s.

## Track 2 — Dormant-image / restart (reclaimable BSD-style cache)

**Model.** On process exit, instead of freeing the binary's banks, keep the
**relocated CODE banks** resident as a *dormant image* keyed by **inode+mtime**.
Data/BSS is NOT kept verbatim (the process dirtied it): the dormant image caches
the relocated code + a **pristine data/BSS template**; each restart re-inits the
data banks (cheap) and re-attaches the code (skips disk read AND relocation).

**Restart path (in spawn/`Load_Binary`):**
1. Resolve path → inode+mtime.
2. Look up dormant registry. Hit (matching inode+mtime, code banks resident) →
   allocate fresh data/BSS banks, copy from the template, bump code-bank refcount,
   build the child on the shared code → **no disk, no reloc**.
3. Miss → full `Load_Binary` (disk + reloc), and on the process's exit register
   the relocated code banks as dormant (refcount 0) instead of freeing them.

**Reclamation (honors BSD memory model — cache, not reservation).** Hook the
**bank allocator** (`Bank_Alloc`/MM), not just `malloc`: on allocation failure,
evict dormant images (LRU) freeing enough banks, then retry; only return ENOMEM
when nothing dormant remains. `malloc()`/`SYS_MALLOC32`/spawn/loader all benefit
because they all bottom out at `Bank_Alloc`.

**Concurrency / shared text.** Code banks are read-only after reloc → shareable
across concurrent instances of the same binary, refcounted. A dormant image is
re-attachable only at refcount 0; a live instance blocks reuse of *its* data banks
but the code banks stay shared. Reuse the existing **shared-libc pile** machinery
(registry + refcount + bank-affinity) rather than a parallel system — the libc
pile is already a resident refcounted shared-code precedent.

## Track 3 — Boot fastload module + `/etc/fastload.conf`

A boot-time module reads `/etc/fastload.conf` (user-editable list of hot binaries:
vi, sh, ls, …) and, for each, does a **load-and-cache-only** pass: load + relocate
+ register-dormant, WITHOUT spawning a process. Boot is allowed to take as long as
it needs; afterward the configured binaries launch warm (via Track 2 restart).
- Needs a loader entry that loads+relocates+registers-dormant without a TCB/spawn.
- Memory budget: cap the fastload set; Track 2 reclamation is the backstop if the
  set + running processes exceed RAM.
- Invalidation: inode+mtime (a rebuilt binary re-loads, not served stale).

## Sequencing & measurement (closed-loop, vi-start-to-paint harness)

1. **B** — fix the B1 boot regression, land, measure cold-load delta vs 3.92 s.
2. **Track 2** — dormant/restart; measure a warm re-launch (target ~instant) and
   verify reclamation frees banks under pressure (spawn-storm / malloc-to-fail).
3. **Track 3** — fastload module; measure post-boot first-launch of a cached binary
   (should be warm) and boot-time cost of the fastload set.

Each lands one change at a time, closed-loop; FS/block/MM are concurrency-hazard
classes. Toolchain-first where a change touches fcc/libc; kernel changes gated by
the tiered test cadence + full gate before land; never push feat branches.

## Fable review — corrections APPLIED (2026-07-20)

**MAKE-OR-BREAK (A): the data bank is BAKED into the relocated code — verified.**
`FGX2_CALLEE_ENTER` (toolchain/lib/macros.s) emits `LDA #bank / PHA / PLB` and the
loader patches the immediate with the data seg's runtime bank (fgx_ld `data_bank`
reloc; >1000 in vi). `long_ptr` relocs bake banks into the data segment too. So
"share code banks + fresh per-instance data bank" corrupts instantly, and
concurrent shared-text is IMPOSSIBLE without a toolchain change.
- **DECISION — Track 2 = Option 1:** a dormant image pins its ENTIRE bank set
  (code + data). Re-attach = re-fill the pinned data bank from a RAM template
  (one ~64KB MVN ≈ 0.2s) + rebuild TCB/stack/DP/args. Zero disk, zero reloc, zero
  Bank_Alloc on the hit path. **One live instance per image**; a 2nd concurrent
  instance falls back to a cold private load. No shared text (yet).
- **QUEUED — Option 2 (toolchain-first, later):** change `FGX2_CALLEE_ENTER` to
  `LDA <dp_cell` (spawn writes the task's data bank to a reserved DP cell) —
  deletes the callee_enter reloc class, makes code banks data-bank-agnostic, and
  unlocks true shared text. (Still needs data-seg `long_ptr` relocs re-applied for
  concurrent sharing — cache the small data-targeting reloc subset then.)

**Template capture is at LOAD time** (post-reloc, post-BSS-zero, pre-entry), NOT
exit (data is dirty by exit). Track 2 cold path + Track 3 both snapshot then.
For `n_data_segment==0` binaries, snapshot the whole seg0 bank.

**Invalidation:** key the registry on raw **(dev, ProDOS key block)** (not in-core
inode slots — they recycle). ProDOS mtime is minute-granularity → a rebuild within
a minute silently runs stale code (exactly our dev loop). FIX: extend fgx_ld's
24-bit segtab checksum to ALL segments, and verify-on-hit by reading ONE block
(header+segtab) and comparing. Closes key-block reuse too.

**Reclamation:** hook `Bank_Alloc` `@balloc_mmFail` ONLY (single choke point,
spawn/loader context). Eviction body is LEAF-ONLY: registry bookkeeping +
Bank_Free/DisposeHandle — no FS calls, no yields, no touching `_ld*` loader
singleton (Bank_Alloc is called mid-load with fd open). Under Option 1 a re-attach
allocs zero banks, so the "evict while attaching" deadlock can't occur; still,
lookup→refcount++ must be one non-yielding stretch (preemption + Fs_ReadN yields).

**TCB seam:** shared/pinned banks must NOT sit in `TCB_BankList` (exit frees every
nonzero entry — task.s:124). Add `TCB_ImageId` (à la `TCB_LibcBank`);
`_Task_FreeBanks` sees it and decrements the image refcount instead of freeing.
Re-attach must still populate `TCB_DataBank` / the entry-DBR the way
`_Loader_StageArgs` expects. New registry table (the libc-pile's single static slot
has no dormancy — reuse the PATTERN, not the code).

**Dormant image holds a libc-pile ref** (`_libcShRef`) so the pile isn't freed out
from under it (pile becomes effectively resident — acceptable).

**Template storage = RAM** (1 bank/image + one MVN on restart). Re-read-from-disk
loses (~100+ blocks for the data seg + reloc re-patching). Track 3 free-bank floor
is a CONFIG value (Bank_Alloc overflows into MM-claimed banks; the 22-bank pool is
a working set, test runs -ramsize 8M).

**Other gaps noted:** wild-store from a buggy run can poison a pinned code bank ->
persistent corruption until eviction (debug-build sampled checksum-on-attach;
policy: do NOT register after abnormal/signal exit). FGX1 binaries never cacheable.
Track-2 metric = the SECOND launch in one boot session (needs an
exit-and-relaunch keystroke script). loader.s still carries TEMP PERF-CAMPAIGN
markers to revert before land.

## Sequencing (revised after B1 died)
B1 is dead (see findings), B2 is deferred/invasive. So: **Track 2 (Option 1) →
Track 3**, B2 optional later. Track 2 is independent of any cold-load work.

## Track 2/3 — implementation skeleton (incremental, closed-loop)

**Registry (new kernel structure).** A small fixed table (kernel heap block; ~8
entries, config cap). Each entry:
`{ key=(dev, ProDOS keyblock), segChecksum (24-bit, all segs), codeBanks[], dataBank,
   templateBank (pristine data snapshot), entryOff, libcPileRef, refcount, lruStamp }`.
Add `TCB_ImageId` (registry index; 0=none) to the TCB struct.

**Track 2 steps:**
1. **Exit seam.** `_Task_FreeBanks` (task.s): if `TCB_ImageId != 0`, DECREMENT the
   image refcount instead of freeing its banks; the image survives at refcount 0
   (dormant). Shared/pinned banks must NOT be in `TCB_BankList` (which exit frees).
2. **Load-time capture + register.** In Load_Binary success (post-reloc,
   post-BSS-zero, PRE-entry): alloc a `templateBank`, MVN the data bank into it,
   create/reuse the registry entry (refcount=1, banks pinned), set `TCB_ImageId`.
   Populate `TCB_DataBank`/entry-DBR the way `_Loader_StageArgs` expects. FGX1 →
   never register. Abnormal/signal exit → do NOT keep dormant (deregister+free).
3. **Restart path** (top of spawn, before Load_Binary): resolve path → (dev,
   keyblock); look up registry; on hit read ONE block (header+segtab) and compare
   `segChecksum`; if match AND refcount==0 (dormant) → **re-attach**: MVN
   `templateBank → dataBank` (re-init), bump refcount, set `TCB_ImageId`, build the
   child on the pinned banks (no disk, no reloc). Miss/mismatch/in-use → cold
   private `Load_Binary` (step 2 path). **MEASURE the 2nd launch** (target ~0.2s).
4. **Reclamation.** `Bank_Alloc` `@balloc_mmFail`: evict LRU dormant (refcount==0)
   images — leaf-only (registry bookkeeping + Bank_Free/DisposeHandle, NO FS/yields/
   `_ld*` touch) — freeing enough banks, then retry; ENOMEM only if none dormant.
   `lookup→refcount++` must be one non-yielding stretch. Test: spawn-storm to force
   eviction; verify banks reclaimed and correctness held.
5. Dormant image holds a `libcShRef` so the pile isn't freed under it.

**Track 3 steps:**
1. **Load-and-cache-only entry:** a loader path that runs step-2's
   load+reloc+capture+register but WITHOUT a TCB/spawn (image parks dormant,
   refcount 0). 
2. **Boot module:** reads `/etc/fastload.conf` (one binary path per line), calls
   the load-and-cache-only entry per line. Runs late in boot (post-FS, post-shell-
   spawn readiness). Boot is allowed to take longer.
3. **Config:** a free-bank FLOOR (config value) so fastload leaves headroom;
   Track-2 reclamation is the backstop. MEASURE: post-boot first-launch of a
   fastload'd binary (should be warm) + the boot-time cost of the set.

**Toolchain follow-up (Option 2, later, toolchain-first):** change
`FGX2_CALLEE_ENTER` (macros.s) from `LDA #bank / PHA / PLB` to `LDA <dp_cell / PHA
/ PLB` where spawn writes the task data bank to a reserved DP cell — deletes the
`data_bank` callee-enter reloc class (most of vi's >1000 relocs), makes code banks
data-bank-agnostic, and unlocks TRUE shared text (concurrent instances share code).
Still needs the data-seg `long_ptr` relocs re-applied per instance for concurrent
sharing (cache that small reloc subset then).

**Harness note:** Track-2's metric is the SECOND launch in one boot session — needs
an exit-and-relaunch keystroke script (kernel-injected input path makes it
headless-able); the existing vi-start-to-paint harness measures only the first.

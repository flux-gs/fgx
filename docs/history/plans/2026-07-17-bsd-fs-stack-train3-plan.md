# Train 3 — BSD FS stack (plan of record)

**Campaign:** `docs/history/plans/2026-07-16-bsd-foundations-campaign.md`
(BSD foundations). Trains 1 (library family, P1 released v1.7.0) and 2
(MM-native malloc, released v1.8.0 / toolchain v1.13.0) are done. This is
**train 3**, the last of the three high-priority trains.

**Branch:** `feat/bsd-fs-stack` (tag `pre-bsd-fs-stack` on main before merge).

**Status:** architecture DECIDED (the maintainer, 2026-07-17 — pointer-shared inode +
buffer cache, singleton retired outright). **Hardened after a Fable design
review** (same date): F0.5 inventory intermediary inserted, durability ordering
fixed, `B_BUSY`/`WCHAN_BUF` + pool-deadlock rules pinned. **F0 DONE 2026-07-17**
— interleave harness built + corruption localized to the tree switch-back;
a deterministic *userland* red bar proved unreachable (multi-block hypothesis
disproven), so the deterministic proof moved to a kernel probe in F0.5 (the maintainer's
ruling). Increments F0 ✓ · F0.5 ✓ · F1–F5 below. **F0.5 DONE 2026-07-17** — `_fwDataBlkIdx`
invalidated on switch-in + boot-time completeness probe (FSPROBE), 9/0.

---

## Goal (the maintainer's scope note, 2026-07-16, verbatim intent)

Retire the `_fsFileState` write-state **singleton** into genuinely per-FCB
state — i.e. the full BSD-style FS stack: **shared in-core inode table +
buffer cache + per-FCB file state** — deliberately shaped as the foundation
for **proper preemptive multitasking**. Once no FS state is implicitly "the
one current writer's", tasks can interleave at any granularity. This train
**closes with the re-applied cooperative kbd-yield** (reverted 2026-07-15
only because two-writer interleaving broke the shared write-state).

**Acceptance for the train:** `tools/mame_test/tests/coop_yield.json` green
(bg `tar cf b.tar ntp &` + live fg `echo YIELDOK`, no `tape write error` /
`unexpected EOF` / `PANIC`), plus byte-exact bg-write artifacts.

---

## What's singleton today (the target of the migration)

Grep-confirmed on `feat/bsd-fs-stack` (src/drivers/fs/fs.s, include/fs.s):

- **`_fsFileState`** (FST_* fields): InUse, Storage, 24-bit Eof, 24-bit Pos,
  CurBlk, KeyBlk, DevIdx, CurMaster, CurIdx — the single-slot "current file"
  globals.
- **Nine `_fw*` write-state globals:** `_fwDataBlk`, `_fwDataBlkIdx`,
  `_fwIdxBlk`, `_fwBlocksUsed`, `_fwDirBlock`, `_fwDirEntryOff`, `_fwDirty`,
  `_fwIdxDirty`, `_fwMasterDirty`.
- **`_fsDataBuf`** — the single 512 B data buffer (+ index/master buffers).
- **`_fsCurOwnerFcb`** — which FCB the globals currently reflect.

The FCB **carries per-FCB slots** for most of this (`include/fs.s`):
`FCB_Eof` (3), `FCB_Pos` (3), `FCB_KeyPtr`, `FCB_DataBlk`, `FCB_DataBuf`
(long ptr), `FCB_IdxBlk`, `FCB_IdxBuf` (long ptr), `FCB_MasterBuf` (long ptr),
`FCB_BlocksUsed`, `FCB_FwDirEntryOff`, `FCB_RefCount` — and they are Kmalloc'd /
Kfreed (`fcb.s`). **But the read/write hot path does not use them:**
`_Fs_SwitchToFCB` is a **disk round-trip** — on switch-away it `Blk_Write`s the
dirty singleton buffers to disk and reloads the new file from disk (verified,
`fs.s` ~1590–1700), *not* a pointer swap; and `Fs_WriteN`'s fast path writes
straight into the singleton `_fsDataBuf`. So the FS is only *half* migrated: the
per-fd backing store is allocated but bypassed. **F1–F3 are therefore an
access-path rewrite (build the cache, reroute every access site), not a rewiring
of existing buffers** — do not undersize the effort.

**The confirmed latent bug** (found 2026-07-15 attempting the yield):
`_Fs_SwitchToFCB`'s sap/tree reload (`@sw_sapOK`/`@sw_treeDone`) restores
`_fsDataBuf`/`_fwDataBlk` but **not** `_fwDataBlkIdx` (only the seedling path
sets it) → the same-block/transition cache is stale after a switch-back.
Restoring `_fwDataBlkIdx` alone did **not** fully fix it, so more state
(`_fwDataBlk`, the index/master dirty caches, `_fsCurOwnerFcb` on a closed peer
fd) needs to be genuinely per-FCB.

---

## Architecture (decided — the maintainer, 2026-07-17)

**The BSD model, and the only one that sets up preemption, is: mutable FS
state lives in *shared* structures reached *by pointer*, never in a scratch
working-set singleton that spans a sleep/yield point.** Concretely, 2.11BSD:

- the open-file description (≈ FCB) holds essentially just the **offset** + a
  pointer to the in-core inode;
- the **in-core inode** (`iget`/`iput` table) holds `i_size`, the block map,
  dirty flags, refcount — **shared** by every fd on the file (this is what makes
  a growing file instantly visible to a concurrent reader, with no sync);
- **data blocks** live in the **shared buffer cache** (`getblk`/`bread`/
  `bwrite`, keyed by device+block#), borrowed per-operation, with a per-buffer
  `B_BUSY` lock a sleeping task keeps held (others block on it).

`_fsFileState` + the nine `_fw*` globals + `_fsDataBuf` are exactly the scratch
working-set BSD does **not** have. The yield-safety criterion is not
"preemptive vs cooperative" (even classic Unix is non-preemptible in kernel
mode, switching only at sleep points) — it is: **does the FS keep mutable state
in a scratch singleton across a sleep/yield?** Today FGX does, which is the
2026-07-15 `tar` corruption; BSD does not, because it holds a *busy buffer* and
re-derives from inode/buffer pointers after waking.

**Ruling (the maintainer): the destination is B — retire the singleton outright, shared
inode + buffer cache, FCB holds `{offset, inode*}`; `_Fs_SwitchToFCB` and its
swapped globals are deleted (F3).** The pointer-shared model is the end-state, not
a coherent swap.

**Amended after Fable review (2026-07-17): insert an aligned intermediary,
F0.5, whose kept artifact is the *complete per-file write-state inventory* — not
a divergent quick-fix.** The deciding fact is above: the partial `_fwDataBlkIdx`
fix did **not** fully work, so *we do not yet know the complete set of per-file
mutable state*. A coherent swap cannot go green without that full enumeration —
and that enumeration is exactly the field-by-field spec F1–F3 re-home into the
inode + buffer cache. Going straight to B discovers the inventory *during* the
un-bisectable F3 rewrite with no oracle; proving completeness first (in the old
representation) and *then* changing representation is the more BSD-honest
ordering, because BSD's correctness property is that the inode + busy buffer
**completely** capture per-file state — completeness is the invariant,
pointer-vs-swap is only the representation. **What's thrown away is ~20 lines of
save/restore; the validated inventory is kept and load-bearing.**

**Yield-safety criterion + the buffer invariant.** The hazard is not
"preemptive vs cooperative" (classic Unix is non-preemptible in kernel mode,
switching only at sleep points) — it is *does the FS keep mutable state in a
scratch singleton across a sleep/yield?* Today FGX does (the 2026-07-15 `tar`
corruption); BSD does not. The wait/wakeup machinery this needs **already
exists** on main (`_sleep`/`_wakeup` on `WCHAN_KBD/SOCK/PIPE`, proven in
`pipe.s`/`net_dispatch.s`); a `WCHAN_BUF` is one more channel. **The invariant
that makes it correct (F2): never `_sleep` while holding `B_BUSY` — yielding
(staying READY) is fine, blocking is not.** A buffer-holder that goes BLOCKED
while busy has no fallback-runnable to wake it, and since `@sw_none` now *idles*
(not halts — the `sched.s:366` "swtch HALTS" comment is stale), that fails as a
**silent hang**, not a clean panic. Buffer wakeup is task-context (block I/O is
synchronous, no IRQ completion), so the lost-wakeup race `_sleep`'s IRQ-mask
guards doesn't even apply here — simpler than the pipe case.

---

## Increments (each rung green through its gate before the next opens)

### F0 — regression baseline + interleave harness — ★DONE 2026-07-17
**Outcome (executed; a cheap deterministic *userland* red bar proved
unreachable — that is a finding, not a gap):**
- **Regression baseline** on the clean (reverted) kernel: `tar_fg_big`,
  `wn_tree`, `wn_sapling`, `stattest`, `synctest`, `fswtest`, `shell_smoke`
  green — the pre-train FS floor.
- **Deterministic two-writer interleave harness built** — `synctest`
  parametrized (`synctest <fill> <path> <nbytes> [slp]`, chunked writer that
  sleeps only past 128 KB so two writers co-occupy TREE state); fixtures
  `fs_twowriter_sap` / `fs_twowriter_tree` run two writers (A bg + B foreground
  as a separate pasted line — jsh won't chain after `&`) that interleave via
  **committed `SYS_NANOSLEEP`, no kbd-yield**.
- **Localization:** sapling interleave is clean; tree interleave is clean even
  at 128 tree switch-aways/writer. **The multi-block `Fs_WriteN` hypothesis is
  DISPROVEN** (write.s 191–314: `_Fs_SwitchToFCB` runs once at entry, the bulk
  loop holds no switch/sleep, so a multi-block write is atomic and reaches no
  state a single-block write can't; `_fwn*`/`_frn*` aliasing is rebuilt per
  entry). So two clean writers can't stage the defect regardless of density —
  it needs a *dirty-tree-metadata-at-switch* coincidence, most likely the
  shell's **resolver/open churn** (`_fsDirBuf` singleton + `spawn` opening fresh
  FCBs), which the original tar+shell repro drove via the (now-lost) kbd-yield.
- **Ruling (the maintainer, 2026-07-17):** do **not** chase a userland red bar (density
  or kbd-yield archaeology). The deterministic proof moves to a **kernel probe
  in F0.5** (below). `coop_yield.json` is reserved as **F5's** acceptance test.
- **Reserved for later increments:** the same-block `B_BUSY` contention fixture
  (F2) and the `Fs_WriteN` re-benchmark (F2, routes its fast path through
  `getblk`). The two-writer fixtures stay out of the green gate until F3 flips
  them (tree) to expect clean.

### F0.5 — kernel FS-state probe + write-state inventory — ★DONE 2026-07-17
**Outcome (committed `0cd37bd5` fix + `543baae8` probe; 9/0 incl. fsprobe_check):**
- **Fix:** `_Fs_LoadStateFromFCB` **invalidates** `_fwDataBlkIdx = $FFFF` on every
  switch-in. NOT a `Pos>>9` recompute — that first attempt REGRESSED
  fswtest/fswtest_tree to FSWBAD, because at a block boundary `Pos>>9` is the NEXT
  block while `_fsDataBuf` still holds the previous one, so a match mis-routes the
  write. Invalidation forces the write path's transition (flush current, load
  target), provably safe. Inventory rule for F1-F3: *the same-block cache is
  invalidated on switch-in, never carried stale.* `_fwMasterDirty`/`_fwIdxDirty`
  are already self-consistent (cleared by the switch-away flush) — no change.
- **Probe:** `_Fs_Probe` (FSPROBE EQU 1, include/fs.s) runs once after Fs_Init,
  save→clobber→load→assert on a scratch FCB, logs `FSPROBE: PASS/FAIL` to dmesg
  (Kern_LogStr). Validated red→green (FAIL with the fix off, PASS on). Active
  forward guard through F3, deleted with the singleton. Caveat: FSPROBE=1 grows
  the kernel → `w5100_patchsites.s` regenerated to match (toggling needs a regen).


**Step 1 — the deterministic corruption proof (replaces the userland red bar),
an `#ifdef DEBUG_FSPROBE` kernel hook:** force one `_Fs_SwitchToFCB`
away-then-back while a tree file holds **dirty master/index from a fresh
allocation**, then assert the reloaded `_fwDataBlkIdx` / `FST_CurIdx` /
`FST_CurMaster` / index+master dirty caches match the pre-switch truth. If the
restore is incomplete (the known gap, above) the assert fires — the bug proven
with **no `_fwSyncTick` timing race**. This is **not throwaway**: the assertion
*is* the "complete per-file write-state inventory, validated" — the completeness
oracle F1–F3 re-home field-by-field. Keep it a `DEBUG_FSPROBE` regression through
F3, delete after.
**Step 2 — make the probe pass** by completing the swap restore in
`_Fs_SwitchToFCB` (`_fwDataBlkIdx`, `_fwDataBlk`, index/master dirty caches,
`_fsCurOwnerFcb` on a closed peer fd, full `FST_*` set). The ~20 lines of
save/restore are deleted in F3; the *validated inventory* is the kept artifact
and the field-by-field spec F1–F3 consume. Gives a bisectable green baseline
before the un-bisectable F3.

**★ Execution notes (grounded 2026-07-17, ready to implement):**
- **Confirmed userland-unreachable both ways.** `fs_twowriter_tree` (two data
  writers, `nanosleep` interleave) AND `fswtest 163840` (single writer + `/bin/ls`
  **open-churn** every 4 blocks, deterministic switch) both come back **CLEAN**.
  The gap is **latent**: `@sw_tree` reloads the correct data block from
  `_fwDataBlk` regardless, so a stale `_fwDataBlkIdx` doesn't mis-route a single
  writer's appends. Only a **field-completeness assertion** exposes it — confirming
  the probe (not an end-to-end test) is the right oracle.
- **The gap, code-confirmed** (fs.s): `_Fs_SaveStateToOwner` (1901) saves block
  *numbers* (`_fwDataBlk`→`FCB_DataBlk`, `_fwIdxBlk`→`FCB_IdxBlk`,
  `_fwBlocksUsed`, `_fwDirBlock`, `_fwDirEntryOff`, `_fwDirty`→`FCB_FL_DIRTY`) +
  `FST_*` (Storage/DevIdx/KeyPtr/Eof/Pos); `_Fs_LoadStateFromFCB` (2073) is the
  inverse. **Neither touches `_fwDataBlkIdx`** (the 16-bit resident-block logical
  index the write path checks at prodos.s:1070 `KAD_fwDataBlkIdx` = `$F5B5`).
  `@sw_tree`/`@sw_sapling` reload the buffers but never set it (only the seedling
  path sets it =0, fs.s:1788). `_fwIdxDirty`/`_fwMasterDirty` are self-consistent
  (cleared by the switch-AWAY flush).
- **Fix (recommended, local, no FCB-layout change):** on the reload paths
  (`@sw_tree` `@sw_treeData`, `@sw_sapling`, and the `_Fs_LoadStateFromFCB` data
  reload) set `_fwDataBlkIdx = Pos>>9` **iff `_fwDataBlk != 0`**, else `$FFFF`
  (invalid sentinel — never collides; max real idx ≈ 32768). Mirrors the existing
  `@sw_treeIdxInval` `CurIdx=$FFFF` pattern. Alternative (per-FCB save/restore)
  needs `FstPriv` 19→21 / `FCB_SIZE` 33→35 (under the 40 soft cap) — heavier;
  prefer recompute.
- **Probe (recommended, no new syscall/tool):** a **boot-time `DEBUG_FSPROBE`
  self-test** run after FS init — seed the file-state globals with a sentinel
  `_fwDataBlkIdx` (+ Eof/Pos/blocknums), point `_fsCurOwnerFcb` at a scratch FCB
  (FCB_Flags = file: none of CONSOLE/CHARDEV/DIR set), `JSR _Fs_SaveStateToOwner`,
  clobber the globals, `_fcbPtr`=scratch, `JSR _Fs_LoadStateFromFCB`, then assert
  `_fwDataBlkIdx == sentinel`; print `FSPROBE: PASS`/`FSPROBE: FAIL` to the console.
  Red before the fix (idx not round-tripped), green after. Deterministic, no MAME
  timing, no tool. Verify the FS regression baseline stays green after the fix.

### F1 — shared in-core inode table  *(the EOF/metadata home)*
Introduce the heap-resident inode table **alongside** the existing state
(train-2 MM-backed `malloc`, DP via `_kHeapCur` — **no new DP slots**, that's
why phase 0a mattered). Keyed by (dev, key-block); refcounted `iget`/`iput`.
FCB gains an inode pointer. Migrate every EOF/size read+write to go through the
shared `i_size`, so a concurrent `cat`/`ls`/`tail` sees live EOF with **no**
explicit sync. **This retires only `_fwSyncTick`'s *visibility* role — NOT its
durability role.** `_fwSyncTick` is *also* the only periodic data+index
write-back to disk before close; it must stay live (or be replaced by F2's
write-back policy) so no increment removes periodic durability. 2.11BSD
`inode`/`iget` semantics sized to FGX. **Refcount ownership rule (specify):** the
in-core inode refcount (`iget`/`iput`, shared across fds) is distinct from
`FCB_RefCount` (open-file-description refcount); state exactly who decrements
what on `close`/`dup`/spawn-inherit — a wrong rule is a use-after-free of a heap
inode. Gate green with the old buffer path still in place.

**★ Execution design (grounded 2026-07-17):** F1 is the LARGEST increment
(> F0+F0.5 combined) — a heap structure + iget/iput + an FCB-layout change +
re-routing size. Landscape:
- **Today:** the file's EOF (i_size) lives in `FCB_Eof` (3B, per-FCB) + the
  `_fsFS_Eof` singleton working copy; growth updates `_fsFS_Eof` +
  `KAD_fsFS_Eof` + the on-disk dir entry (prodos.s ~813/872). A concurrent
  `Fs_Stat` reads the **on-disk dir entry** via `_Fs_DirEntryToStat` (fs.s:865),
  so a reader sees a size that lags until `_fwSyncTick` (~1s). That lag is what F1
  removes.
- **Inode struct** (heap; keyed by `(dev, key-block)` = a file's ProDOS
  identity): `i_dev`, `i_keyblk`, `i_size` (24-bit), `i_count` (refcount),
  `i_flags`/dirty. Fixed table of 16 slots × 8 B. **As built (slice 1a):** the
  table SHARES the block table's Kmalloc'd heap block at `+INODE_TAB_OFF`
  (`INODE_USE` macro; `_BlkTab_Init` allocs+zeros 256 B) — KGlobals is at its
  `$02FE00` ceiling, no room for a 2nd base static. DP access via `_kHeapCur`
  (no new DP slots).
- **`iget(dev,keyblk)`** find-or-alloc + `i_count++`; **`iput`** `i_count--`,
  release slot at 0. **Refcount rule:** `i_count` counts FCBs pointing at the
  inode (an FCB gets one inode ref for its lifetime); `FCB_RefCount` (f_count)
  counts fd-table slots per FCB and is unchanged. `Fs_Open`→`iget`;
  `_Fcb_Free` (the real close, at f_count 0)→`iput`. spawn-inherit bumps
  `FCB_RefCount` only (same FCB → same inode), NOT `i_count`.
- **FCB slot (SUPERSEDES the earlier 3-B far-ptr design):** add `FCB_Inode` as a
  **1-byte slot index** (COMMON field after `FCB_RefCount`; `INODE_NONE`=$FF
  sentinel — NOT 0, 0 is a valid slot) → `FstPriv` stays 19, `FCB_SIZE` 33→34
  (under the 40 soft cap; `FCB_SIZE` is computed + `_Fcb_Alloc` Kmallocs it, so
  growth is clean). A slot index beats a far ptr: 1 byte vs 3, and the table
  base is macro-derived so no stored pointer can dangle.
- **Route i_size:** write-growth also writes `i_size` in the inode; `Fs_Stat`
  looks up `iget`-style `(dev,keyblk)` first — if an in-core inode exists, use its
  live `i_size`; else fall back to the dir entry. Immediate cross-process
  visibility, no `_fwSyncTick` dependency for *visibility* (durability role of
  `_fwSyncTick` stays).
- **Slices (each gate-green):** (1) inode struct + table + `iget`/`iput` +
  open/close hooks + `FCB_Inode`, **no behavior change** (regressions green,
  inodes alloc/free/refcount correctly — add a probe/dmesg count like FSPROBE).
  **Slice 1a ✓ DONE** (`88b5f851`): table + `_Inode_Get`/`_Inode_Put` +
  `_Inode_Probe` boot self-test (`INODEPROBE: PASS`), inodes inert, 9/0 green.
  **Slice 1b (next):** `FCB_Inode` + hooks in **BOTH `Fs_Open` AND `Fs_Create`**
  (creat() mints the writer's regular-file FCB — hooking only Fs_Open would
  leave the exact fd slice 2 routes growth through inode-less), placed AFTER
  `_Fs_MarkNewOwner` (its save-mirror populates the FCB's dev/keyblk);
  `_Fcb_Free`→`iput` at `@fr_doFree`. **Table-full policy:** `_Inode_Get` C=0 →
  store `INODE_NONE`, open SUCCEEDS; every `FCB_Inode` consumer treats NONE as
  "fall back to the dir-entry path" (reachable: 8 fds/process × several
  processes > 16 slots). **Slice 1b ✓ DONE** (`97b460ce`): FCB_Inode +
  `_Fs_InodeAttach` in Fs_Open+Fs_Create + `_Fcb_Free` iput; live-memory
  no-leak probe green. (2) **✓ DONE** (`31c15122`): `_Fs_InodeSyncSize`
  mirrors singleton EOF+KeyBlk into the owner's inode at all three
  write-success exits; `_Fs_InodeAttach` seeds i_size on FRESH allocs only
  (`_Inode_Get` A.hi fresh flag — dedup must not clobber a live writer's
  size).
  **Promotion landmine — HANDLED in slice 2:** ProDOS promotion (seed→sap→
  tree) changes the file's key_pointer; the per-write sync re-keys the
  writer's inode from `FST_KeyBlk` in the same stroke, so a post-promotion
  open still dedups (proven: mid-write inode key == post-close dir-entry key
  across identical-allocation probe runs).
  (3) `Fs_Stat` reads in-core `i_size` (NONE/miss ⇒ dir entry) → **new
  visibility test** (bg slow writer + fg `ls -l`/stat sees the live growing
  size with NO sync, tighter than `synctest`'s ~1s). Keep the old dir-entry
  path as fallback throughout.
- **Scope note (reader EOF):** F1 delivers live size via **stat/ls only**. A
  reader fd's own `Pos>=Eof` bound (Fs_ReadN) is loaded at open and NOT
  refreshed from the inode, so `cat`/`tail` on a growing file still sees
  open-time EOF. That migration is **deferred to F3**, where the FST_*/`_fw*`
  working set is rewired through the inode — the F1 intro's "cat/tail sees
  live EOF" lands there, not in F1.

### F2 — shared block cache UNDER `Blk_Read`/`Blk_Write`  *(the data-block home)*
**✓ DONE 2026-07-17 (`5300bafe`)** — all three slices sequentially gated
(BLKPROBE + 10/0 each; final gate: 16/16 slots live, 105 read hits in ~5 s).
KEY TRAP fixed en route: boot Blk_Reads precede `_BlkTab_Init`, so every
cache entry point carries a not-ready guard (`_kBlkTabBase` bank byte 0 ⇒
off) — any future Blk-funnel hook must do the same.
**★ Re-shaped 2026-07-17 (grounded + Fable-reviewed).** The original
getblk/brelse rewrite would touch ~300 buffer reference sites (`_fsDirBuf`
alone: 85 kernel + 121 module). But ALL block I/O — kernel AND prodos.mod
(via `JSL SYS_BLKREAD/SYS_BLKWRITE`) — funnels through exactly two ENTs,
`Blk_Read`/`Blk_Write`, with `(dev=_fsCurDevIdx, blk=_blkNum, buf=_blkBuf)`
in hand. So the cache lands UNDER the funnel, transparent to every site; FCBs
start holding pool POINTERS in F3 (that's where getblk/brelse semantics
appear). F2 invariant: **a valid pool entry is byte-identical to disk** —
every case reasons from that, never from allocation patterns.
- **F2-a — pool core, inert:** 16 × 512 B buffers + header table (dev, blk,
  valid, LRU tick) in one Kmalloc'd block (own bank OK; **MULTIBANK_VERIFIED
  gate**); lookup + LRU-alloc internals; `BLKPROBE` boot self-test, which must
  also verify the caller-buffer bank assumption (`_blkBuf` is a KERNEL-bank
  offset for every caller, module included — the four FS singletons are
  kernel-bank statics the module reaches via KAD).
- **F2-b — `Blk_Write` hook FIRST** (order matters: landing the read consult
  before the write refresh would serve stale pre-write dir blocks — dir blocks
  are both the hottest and the most rewritten): disk write as today; success →
  refresh/populate the pool entry; **EIO → INVALIDATE** (on-disk state
  indeterminate — a refreshed copy would confidently serve bytes that may not
  be on disk). Whole-cache invalidate wired into unmount AND mount/volume
  rescan (media swap without unmount is a classic ProDOS-era vector). Zero
  behavior change — nothing reads the pool yet; regression run proves it.
- **F2-c — `Blk_Read` consult:** hit → MVN pool→caller buf +
  `_kBlkCacheHits++` (new SYS_KSTAT field beside `_kBlkReadCount`, `vmstat -b`
  visible); miss → disk read into caller buf as today, THEN populate (a
  failed read can't pollute). Best-case load is `_Fs_SwitchToFCB`: every owner
  switch re-reads master+index+data → 3 SmartPort reads become 3 MVNs; dir
  path-walk blocks are the second win.
- **Durability: WRITE-THROUGH, permanently** (ponytail: revisit only if
  `_kBlkCacheHits` shows write-bound workloads). Writes are synchronous today,
  so the durability model is unchanged by construction — no write-back, no
  update daemon, no block-layer flush machinery ever; F4's `fsync`/`sync`
  force FS-level state (`_fwDirty`/inode), not the block layer.
- Ramdisk (`DEV_CLASS_RAM`): cache uniformly for now — the cost is LRU
  pollution, not the sub-ms double-copy, and the hit counter detects it; add a
  per-device no-cache flag only when measurements say so.
- **§3.7 FS-buffer migration: SUPERSEDED** for `_fsDataBuf`/`_fsIndexBuf`/
  `_fsMasterBuf` — F3 deletes those statics outright at the pointer flip
  (migrating first would be moved-then-deleted churn). `_fsDirBuf` is NOT in
  that deletion set — it remains explicitly scoped in F3 below.

### F3 — retire the singleton  *(the point the model is BSD)*
**Inherited invariants (moved here from F2 by the re-shape — F3 is where pool
POINTERS first appear):** per-buffer `B_BUSY`; `getblk`-on-busy = `_sleep` on
`WCHAN_BUF` then re-test (coarse wake-all fine across ≤8 fds); **never
`_sleep` while holding a pool pointer — yield only** (the holder stays the
fallback-runnable that wakes its own readers), or the pool deadlocks; pool
min size ≥ held-per-op × concurrent writers + dir (a tree op holds 3; the
16-buffer pool has slack, and growing it is a one-constant knob).
With the inode + buffer cache now the state homes, rewire the remaining `_fw*` /
FST_* working set through the FCB-by-pointer + inode + buffer cache, then
**delete** `_Fs_SwitchToFCB` (+ F0.5's save/restore), `_fsFileState`, the nine
`_fw*` globals, `_fsDataBuf`, and `_fsCurOwnerFcb`. The FCB is now
`{offset, inode*, dir*}`. Two-writer `tar` interleave is byte-clean as a
*consequence* of there being no scratch singleton to corrupt.
**Also scope `_fsDirBuf`:** the resolver's global dir buffer is itself a
singleton used across path lookup — either bring it into the buffer cache here or
**prove no lookup spans a yield** (and record the proof); a mid-walk yield is the
same bug class. `tar_bg_*` + the switch-heavy + same-block fixtures green.

### F3 — RESEQUENCED OUT OF TRAIN 3 (the maintainer, 2026-07-17 post-F2)
F3 (the ~600-site pointer flip) moves to the PREEMPTION campaign as its
opening train — F0.5+F1+F2 already deliver the yield-safety the original
ruling protected, and Fable's audit found no surviving corruption class that
only F3 fixes (thin/partial F3 explicitly rejected: two-homes split-brain).
The section above stays as that train's plan of record; its two residues fold
into THIS train: switch-EIO latch → F4, dirbuf audit → F5.

### F4 — `fsync(2)` / `sync(2)` on-demand durability
New syscalls **97 (`SYS_FSYNC`) / 98 (`SYS_SYNC`)** (slots free — `SYS_NUM_MAX`
= 96; **remember to bump `SYS_NUM_MAX`**, the M-4 ENOSYS-trap lesson) + libc
wrappers. These *expose on-demand forcing* of the F2 write-back cache: `sync`
flushes all dirty buffers, `fsync(fd)` forces one file. (The periodic
`update`-daemon flush already landed in F2 — F4 is the explicit-force API, not
where durability first appears.) Man pages per policy.

**F4 ✓ DONE 2026-07-17** — SYS_FSYNC=97 (`Fs_Fsync`: LookupPtr → class
filter → `_Fs_FsyncFcb` switch-in + FOP_Flush + latch report → Bm_Sync) +
SYS_SYNC=98 (`Fs_SyncAll`: walks EVERY task's fd table via TCB_FdTablePtr,
loop state stack-relative since the flush core clobbers all scratch; Bm_Sync
once).  Residue-1 CLOSED: the three best-effort switch-away flushes
(data/idx/master in `_Fs_FlushPreviousOwner`) now `_Fs_LatchWerr` →
`FCB_ErrLatch` (new byte, FCB_SIZE 35), reported once at next
write/fsync/close.  libc wrappers on toolchain branch `feat/fsync-sync`;
`sync(1)` ported (2.11BSD 4.1) + man page.  PROVEN by disk-extraction
fixtures: writer spins forever unclosed, MAME dies, extracted image holds
the full 512-byte sha — only the sync could have committed the tail
(fsynctest.json / synctest_all.json).

**Residue-2 CONFIRMED LIVE (F5 pre-work):** `Fs_Readdir` line ~1253 trusts
`_Fs_SwitchToFCB` to have `_fsDirBuf` current, but an interleaved stat/walk
clobbers the buffer WITHOUT an owner change → the fast path serves stat's
leftovers.  Latent only because BSD ls reads-all-then-stats; a find-style
interleave corrupts enumeration.  Fix in F5: unconditional dir-block re-read
per readdir (post-F2 a cache-hit MVN, sub-ms).

### F5 — closing increment: re-apply cooperative kbd-yield
Re-apply the reverted kbd-gated cooperative `swtch` at the syscall dispatcher
exit. **Acceptance:** `coop_yield.json` green + byte-exact bg-write + the
same-block contention fixture green (proves `B_BUSY`/`WCHAN_BUF` actually
works, not just unrelated-block interleave). Preemptive (IRQ-driven) scheduling
stays a **separate later decision** — this train only builds the state model it
requires.

---

## Gates & discipline
- Per-rung: goldens green, MAME **fast + net** green, no MX/canary regressions.
- **MULTIBANK_VERIFIED=1** on F3 (buffer migration crosses banks) and anywhere
  bank-emission-adjacent.
- Feature branch only; hold-releases until the maintainer green-lights the release train
  (toolchain first if any toolchain change — none expected here except the two
  libc syscall wrappers → this is FGX-side; likely FGX-only release).
- `release.sh` is the single gate.

## Ledger / memory
`project_fgx_block_write_and_coop_yield` (the reverted yield + block-write),
`project_fgx_bsd_foundations_campaign` (train sequencing), the
`fgx-bsd-foundations-campaign` the project notes saga. FS internals class:
`project_prodos_tree_phase_a_done` (write-state = recurring singleton class).

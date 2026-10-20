# P3 — FS singleton retirement (implementation plan, chartered 2026-07-18)

**STATUS: RATIFIED (the maintainer, 2026-07-18): "our time will be better served
implementing P3, then troubleshooting from within the new P3 framework if the
bug still persists."**  This supersedes the 2026-07-18-morning "F3 decoupled to
optional cleanup" ruling — four singleton-class casualties in one day
re-chartered it as the campaign's next train.

Branch: continue on `feat/preemption` (held local; toolchain
`feat/loop-safepoints` @ `60eeb397`).  Tag `pre-p3-singleton` exists on an
earlier base — re-tag `pre-p3` at current HEAD (`109d2720`) before starting.
Read `docs/history/plans/2026-07-17-preemption-campaign-roadmap.md` (F3
section) for the full history; THIS file is the implementation truth.

---

## 1. Why now (the evidence that re-chartered it)

Preemption (P1 quantum + P2' safepoints) turned every cross-context singleton
into a loaded gun.  2026-07-18 casualties, all the same class:

1. **F5 dirbuf** — readdir enumeration vs `_fsDirBuf` singleton (BUG 1,
   reverted blanket re-read; BUG 1b multi-block truncation still open).
2. **Dispatcher Y-return singleton** — quantum yield at the F5 hook lost Y
   (SYS_MALLOC32 offset) → wild `free($6D:0040)` (FIXED, `7e4a608f`).
3. **`_fsTmp0/1` survival contracts** — contradictory across callers; the
   disk-miss path clobbered them (FIXED at the Blk_ chokepoint, `3d9b4887`).
4. **The OPEN intermittent spawn corruption** (§6 dossier) — spawn inputs
   arrive at the kernel zeroed/garbled; deterministic repro exists; four
   spot-hypotheses falsified.  Spot-chasing suspended in favor of P3.

P3's bet: replace the singleton **class** (per-FCB/per-context state, buffers
as cache-pool references), and bug #4 either disappears with the class or
becomes observable inside a structure with real ownership.

## 2. Scope

**IN:** the FS working-state singleton and its machinery —
- `_fsFileState`/`_fsDirState` cell block (`FST_*`/`DST_*` at `$F3xx/$F4xx`:
  Pos/Eof/KeyBlk/Storage/DevIdx/InUse, `DST_CurBlk/EntryIdx`, the `_fw*`
  write-state: `_fwDataBlk/_fwDataBlkIdx/_fwIdxBlk/_fwCurMaster/_fwDirty/
  _fwDirEntryOff` …).
- The owner model: `_fsCurOwnerFcb`, `_Fs_SwitchToFCB` (fast path +
  `@sw_isDir/@sw_sapling/@sw_tree` reloads), `_Fs_SaveStateToOwner`,
  `_Fs_LoadStateFromFCB`, `_Fs_FlushPreviousOwner`, `_Fs_MarkNewOwner`.
- The four shared 512 B buffers: `_fsDataBuf`, `_fsIndexBuf`, `_fsMasterBuf`,
  `_fsDirBuf` (module-side aliases `KAD_fsDirBuf` etc.).
- Path resolution's use of `_fsDirBuf` (walk scratch) — gets its OWN read
  path via pool pointers (fixes BUG 1 residual + BUG 1b structurally).

**OUT (follow-on trains — the "generalized F3" register, do NOT scope-pull):**
- Dispatcher carryover singletons (`_Sys_Saved*`, `_Sys_CallerBank`,
  `_Sys_PathBuf`) — partially per-task'd already (SE_* save/restore);
  audit as its own train.
- Userland libc staging cells (`_libc_lstrBufA` universal scratch — spawn
  now private, `60eeb397`; open/fopen/stat staging still shared).
- DP scratch contracts (`_fsTmp*`, `_shTmp*`, `_libcTmp*`) — Blk_ chokepoint
  preserves `_fsTmp0/1` now; full contract audit later.
- The modload boot-window collision with `$1000-$1FFF` kernel stacks
  (canary-caught, boot-only — see `8d7e2b20`).

## 3. Pre-work already banked (don't redo)

- **F0.5** save/load completeness (probe-guarded) — the per-FCB field set and
  its save/load discipline already exist and are gate-proven.
- **F1** shared in-core inode: Eof/Size are inode-backed for regular files —
  P3.2 retires `_Fs_InodeSyncSize` instead of migrating Eof.
- **F2** coherent block cache with **invalidate-on-write** (`99a60c17`):
  a VALID entry ≡ bytes last read from disk.  This is the substrate that
  makes P3.3's held-pool-pointers correct.
- **F3.0** mechanism confirmation: disk stays byte-clean; the failure mode is
  read-side state, not on-disk corruption.
- FCB layout (include/fs.s): 35 bytes used, **soft cap 40** (`ERR` guard) —
  5 bytes of growth budget; `FCB_FstPriv` 19-byte overlay currently uses 19.

## 4. Slices (implement in this order)

### P3.1 — write/block-map state → per-FCB (~230 sites, one solid session)
Move the `_fw*` cells into the FCB (most already HAVE FCB mirrors from F0.5 —
`FCB_DataBlk/IdxBlk/BlocksUsed/FwDirEntryOff`…): the migration is flipping
readers/writers from the singleton cell to `[_fcbPtr],Y` accesses, then
DELETING the save/load copying for the migrated fields.
- Grep inventory: `_fwDataBlk|_fwDataBlkIdx|_fwIdxBlk|_fwCurMaster|_fwDirty|
  _fwDirEntryOff|_fsFS_` across `src/drivers/fs/*.s` + `src/modules/prodos/`.
  Module code reaches FCB fields via `[_fcbPtr]` (already the pattern in
  fcb.s helpers) — the module needs `_fcbPtr` mirrored (`KDP_fcbPtr` exists).
- Growth: new FCB fields needed beyond existing mirrors ≈ 2-3 bytes
  (`_fwCurMaster`, dirty bits fold into `FCB_Flags` bit1) — fits the cap.
- The dirty flag moves to `FCB_Flags` bit1 (already reserved "dirty-data").
- Gate: full 19-fixture FS+P2' set + `bg_tar_spawn` + `heapstomp4` after
  EVERY sub-batch (~50 sites); commit per green batch.

### P3.2 — Pos/Eof/key/storage/dev → per-FCB reads (low risk, small)
- Regular files: Eof from the inode (F1) — delete `_Fs_InodeSyncSize`.
- `FST_Pos` → `FCB_Pos` direct (field exists; kill the save/load round-trip).
- `FST_KeyBlk/Storage/DevIdx` → FCB fields (exist).  After P3.1+P3.2 the
  only singleton left is the BUFFERS + `DST_*` dir enumeration state
  (`FCB_DataBlk/DirEntryIdx` mirrors exist — flip them too).

### P3.3 — the beast: 512 B buffers → held pool pointers (~179 sites, 1-2 sessions)
Replace "copy block into private singleton buffer" with "hold a PINNED
pointer into the F2 cache pool":
- `FCB_DataBuf/IdxBuf/MasterBuf` (long-ptr fields exist, 3 B each) point INTO
  the cache pool entry for the resident block; `_fsDirBuf` dir reads and the
  PATH WALK read via a transient held pointer.
- **Pool pinning:** add `BCH_FL_BUSY` to the cache header flags.  AllocLRU
  skips BUSY entries; Inval on a BUSY entry = flag `BCH_FL_STALE` (drop pin
  on release).  Invariants: max simultaneous pins bounded (NPROC × 3 file
  bufs + walk transient) vs `BLKCACHE_NBUF`=16 — **RAISE the pool to 24-32
  entries** (block-table Kmalloc block grows; `BLKCACHE_OFF/_BUFOFF` math in
  include/fs.s) or enforce pin budget ≤ pool−4.  NEVER sleep/yield holding a
  transient pin (Model A makes syscalls atomic — document the invariant for
  future P4 blocking work).
- **Write path × invalidate-on-write:** a write to a PINNED block updates the
  pool copy AND writes disk (write-through for pinned entries — coherent
  because the pin holder is the only writer under Model A); unpinned entries
  keep invalidate-on-write.  This removes the "read right after my own write
  re-fetches from disk" cost for the hot write path too.
- **The multibank rework:** module code does X-indexed absolute reads
  (`LDA |_fsDirBuf,X`).  Pool pointers make these `[ptr],Y` — the documented
  Y-liveness rework in prodos.s (the reason this slice is "the beast").
  Convert FOP-by-FOP: readdir → stat → open → read → write → mkdir/rmdir/
  rename.  `MULTIBANK_VERIFIED=1` required for the release gate.
- Then DELETE: `_Fs_SwitchToFCB`, `_Fs_SaveStateToOwner`,
  `_Fs_LoadStateFromFCB`, `_Fs_FlushPreviousOwner`, `_fsCurOwnerFcb`, the
  four 512 B buffers (~2 KB bank-$7D reclaimed), and the owner-switch F0.5
  probe.
- **Payoffs beyond correctness:** BUG 1b fixed structurally (readdir holds
  its dir-block pin; no reload staleness); path walk loses its `_fsDirBuf`
  dependence (BUG 1 residual closed); block-boundary yield points inside FS
  loops become SAFE (P0's spawn-latency item — optional followup).

### P3.4 — probes out, regression in
- Remove the TEMPORARY probes (fs.s BUG3 dir-stat snapshot; syscall.s
  CopyPathToBuf EMPTYPATH log + `$031A/$031D` snapshots) once §6's bug is
  resolved.  KEEP the kernel-stack canary (permanent).
- Track `ls_port` (should go fully green once BUG 1b is fixed by P3.3).
- Track `bg_tar_spawn` in the standard gate.

## 5. Acceptance (train)

- Full FS+P2' gate 19/19 **plus** `ls_port` green (multi-block `/bin` listing
  complete) **plus** `bg_tar_spawn` green at gaps 150/420/440 ×3 each
  (the previously-failing phases) **plus** `heapstomp4`.
- `spawn_under_write`, `synctest`, `coop_yield`, `quantum_yield`,
  `spin_yield`, `spin_sigint` unregressed (preemption suite).
- MULTIBANK_VERIFIED=1 sweep for P3.3.
- Kernel-stack canaries silent post-boot (the boot-window modload collision
  is known/accepted until its own fix).

## 6. The suspended spawn-corruption dossier (resume from within P3)

**Symptom:** under `tar -cf ntp.tar ntp &` + repeated fg `ls -l ntp.tar`,
spawns intermittently fail: `jsh: ls: Is a directory (errno 21)` (post-jsh-fix;
formerly blanket "not found").  **Deterministic repro:** `bg_tar_spawn` at
`post_gap_frames=150` (3/3); 440 also fails most runs; 200-400 pass.

**Hard evidence (probes in tree):**
- The kernel walks canonical path `/ROO…` — the final DirEntry2Stat lands on
  entry "ROOT" (storage $D0) at blk 2 off 238 (BUG3 snapshot, `$0310`).
- The spawn handler's path copy consumed `[bank=$00 : off=$0000]` in one
  captured failure (EMPTYPATH slot) — i.e. `A=0` AND `_Sys_CallerBank=0` at
  the handler; another failure had a NON-empty garbled path; a later LAST-slot
  showed `bank=$00 off=$8386` (a bank-0 user-stack-arena address) as a path
  SOURCE.  `_curTask` read 0 mid-syscall once.  jsh SURVIVES each time and
  receives a clean errno — so kernel-stack unwind and exit state stay intact.
- Register-state corruption at/around the JSL, not buffer content:
  write-captures on the staging cell showed NO alien runtime writers, and
  privatizing the spawn staging cell (`60eeb397`) did NOT fix it.

**Falsified:** F2 cache semantics; safepoint toolchain (old-toolchain repro);
kernel-stack overflow (canary + zero-primed watermarks: peaks ~58 B/256);
user-stack neighbor spill (guard page didn't help); staging-cell rewrite
(private cell didn't help); nested-yield atomicity (module SYS_* bridges are
thin wrappers); `_Sys_CallerBank` swtch save/restore (symmetric).

**Standing suspects for the P3-era resume:**
1. Something restores/loses USER REGISTERS (A, DBR) across a quantum
   yield-resume on a path not yet audited — the F5-hook bracket protects
   P/A/Y on the kernel stack, but a SECOND resume path (signal delivery?
   `_Task_FirstRun` priming? the `@sw_idle` wake path?) may not.
2. `_Sys_UserSP`-relative frame reads under a stale/foreign SP after an
   interleaved spawn/exit (task-slot or SE reuse while frames still live).
3. If it persists POST-P3: instrument from the new framework — per-FCB state
   means a corrupted syscall's inputs can be logged against a real owner.

**Ready-to-run next probes (designed, not yet run):**
- Kernel: log EVERY `SYS_POSIX_SPAWN`'s (CallerBank, path-off, first 4 staged
  bytes) — ~10 lines/run; diff good vs bad runs.
- User-side: capture_writes on jsh's private `__fgx_spawn_path` cell (find
  its address via `build/userbin_libcshare_seg0_Output.txt` — it is now
  `_libfgx___fgx_spawn_path` in libfgx_data) during a gap=150 run.
- Harness note: `capture_writes` max_hits caps at 32 plugin-side; use 1-byte
  windows to stay under it.

## 7. Session-start checklist for the implementer

1. `git log --oneline main..feat/preemption` — expect `109d2720` at tip;
   toolchain submodule worktree on `feat/loop-safepoints` @ `60eeb397`
   (gitlink still points at v1.14.0 — REVIEW FINDING: commit the pin).
2. Re-read: this plan; roadmap F3 section; `include/fs.s` (FCB layout +
   region map); `src/drivers/fs/fs.s` `_Fs_SwitchToFCB`/save/load;
   `src/drivers/block/blkcache.s` (pool + header layout).
3. the project notes: `search_memory_facts` "P3 singleton retirement" +
   "spawn corruption dossier" (group `fgx`).
4. Tag `pre-p3` at HEAD.  Work in P3.1-sized batches, gate every batch
   (`run.py` list in §5; tiered cadence per standing policy).
5. Known open review items riding the branch: LATPROBE still `EQU 1`
   (turn off before release); `_fcc_safepoint` X-save hardening optional;
   ls_port untracked until BUG 1b dies.

## 8. Estimates

| Slice | Size | Risk |
|---|---|---|
| P3.1 write/block-map per-FCB | ~230 sites, 1 session | Medium (mechanical, gate-per-batch) |
| P3.2 Pos/Eof/key per-FCB | small, same session as 3.1 tail | Low |
| P3.3 buffers → pool pins | ~179 sites + module Y-rework, 1-2 sessions | HIGH (multibank; the beast) |
| P3.4 probes/regression cleanup | hours | Low |

Release: toolchain first (`feat/loop-safepoints` — safepoints + spawn-staging
+ any P3-era libc changes), then FGX re-pin, per the standing release flow.
HOLD-RELEASES until the maintainer green-lights the train.

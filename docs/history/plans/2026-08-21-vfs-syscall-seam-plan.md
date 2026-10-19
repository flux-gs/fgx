# UFS 1.7d and beyond: giving the VFS a syscall customer

Written 2026-08-21.  Supersedes the 1.7d sketch in
`docs/ROADMAP.md` (the "Next:" paragraph around line 789) and the
`vfssw`/registration sentence in `src/kernel/vfs/vfsops.h:33`.  It does NOT
supersede `docs/history/plans/2026-08-09-ufs-migration-campaign.md`, which
still governs Phases 0-3; this plan replaces that campaign's Phase 1.7
deliverable and re-sequences the entry into Phase 2.

Reviewed by a second model against the repo before adoption.  Three of the
claims in the draft it reviewed were wrong and are corrected inline below,
marked CORRECTED.

## The situation, verified

FGX has THREE layers, and two of them have been called "the FST vtable".

**The FS/FST layer** (`src/drivers/fs/fs.s`, `path.s`, `write.s`,
`src/modules/prodos/prodos.s`) has every userland customer.
`src/kernel/syscall.s:969` dispatches SYS_OPEN to `_Sys_Open`
(`syscall.s:4150`), which calls `Fs_Open`.  Filesystem dispatch is
`JSR _Fst_Dispatch`, 15 sites in `fs.s` and 13 in `write.s`.

**The VFS** (`src/kernel/vfs/`) is 4.3BSD-Reno-shaped and complete:
`struct vfsops` (`vfsops.h:57-63`), `struct vnodeops` (`vnode.h:99`), `v_op`
(`vnode.h:265`), `mnt_op`, namei, the name cache, `vn_open`/`vn_read`/
`vn_write`/`vn_close`/`vn_rdwr` (`vfs_vnops.c`), three vnodeops tables
(`ufs_inode.c:390-434`), `ufs_mknod`, iget/iput with a real inode lock,
directory mutation, truncate.  Five probe gates are green.

**IT HAS NO CUSTOMER.**  `syscall.s` contains zero references to `namei` or to
any `VOP_`.  `src/kernel/main.s:2156-2159` says so deliberately: "An inward
seam returns when 1.6b's namei gives the VFS a syscall-path customer, shaped
by that customer."

### `_FstTable` was never built, and must not be

`include/fst.s:19-22` promises `_FstTable`, an array of 9-byte per-type
records with `FST_MAX EQU 4` and `FST_IDX_PRODOS`/`FAT32`/`CHARDEV`.  It has
no storage anywhere in the tree; the only hits are that promise and the two
"index into _FstTable" field comments at `include/fs.s:108,394`.

What exists instead is ONE cell: `_fst_ops_save`, a 3-byte kernel-bank triple
at `include/memmap.s:707`.  `_Fst_LoadOpsPtr` (`fst_dispatch.s:47-58`) does
`LDA #VT_FST; JSR Mod_FindVtable` and stores the single hit; `main.s:505`
calls it once at boot.  **There is exactly one filesystem, chosen at boot.**
`Mod_FindVtable` is a first-hit linear walk -- `hellofail.s:79` documents that
failure mode on purpose.

`FCB_FstIdx`/`MT_FstIdx` are write-only tags (`fs.s:1842` stamps
`FST_IDX_CHARDEV`, `src/modules/net/pipe.s:189` stamps 0) and are never read
to select ops.  Routing is `FCB_Flags` (`FCB_FL_CHARDEV`, `FCB_FL_PIPE`).

### What BSD does, read from `vendor/4.3BSD-Reno/`

`kern/vfs_conf.c` is the whole per-type table:

    struct vfsops *vfssw[] = {
        (struct vfsops *)0,   /* 0 = MOUNT_NONE */
        &ufs_vfsops,          /* 1 = MOUNT_UFS  */
        ...
    };

It holds `struct vfsops` (`sys/mount.h:125-135`): mount, start, unmount, root,
quotactl, statfs, sync, fhtovp, vptofh, init.  All per-FILESYSTEM.  It is
consulted in exactly one place, `mount(2)` (`kern/vfs_syscalls.c:104,114`):
bounds-check `uap->type` against `MOUNT_MAXTYPE`, then
`mp->mnt_op = vfssw[uap->type]`.

Per-FILE operations are not in that table.  They hang off the vnode as `v_op`,
installed by namei.  `open(2)` does no filesystem-type dispatch at all:

    if (error = falloc(&nfp, &indx)) RETURN (error);
    if (error = vn_open(ndp, fmode, cmode)) { ... }
    fp->f_flag = fmode & FMASK;
    fp->f_type = DTYPE_VNODE;
    fp->f_ops  = &vnops;
    fp->f_data = (caddr_t)ndp->ni_vp;

`read`/`write` go through `fp->f_ops`, which selects vnode-vs-socket, not
filesystem type.

**Conclusion: the 23-slot FOP vtable (`include/fst.s:84-148`, sole instance at
`prodos.s:212-237`) conflates Reno's per-type `vfsops` with per-file
`vnodeops`.  Building `_FstTable` would institutionalise the conflation.  The
line in `include/fst.s` is a promise from before the VFS existed and should be
deleted, not implemented.**  FGX's own `vfsops.h:12-15` already gives the
reason: "a vfsops is chosen once at mount time and a vnodeops is consulted on
every operation."

`vfsops.h:17-33`'s decision that the module registry IS `vfssw[]` stands.  The
VFS's `struct vfsops` keeps Reno's five load-bearing slots and drops
quotactl/sync/fhtovp/vptofh/start with reasons given.

### CORRECTED: three claims in the draft that were wrong

**1.  There is no live VT_FST collision, and no new tag is needed.**  The
draft proposed a "1.7d-a" step to resolve a collision between prodos.mod's
23-slot FOP table and ufs.mod's vfsops, both under `VT_FST`.  ufs.mod's VTDR
is `VT_UFSCORE` then `VT_END` (`ufs.s:99-101`); it declares no `VT_FST` entry
and none is staged.  Nothing needs a registry lookup to reach `ufs_vfsops`:
`ufs_mount` sets `mp->mnt_op = &ufs_vfsops` directly (`ufs_vfsops.c:189`).
**That step is deleted.  Do not mint `VT_VFSOPS`.**  `VT_FST` stays uniquely
prodos's until the FOP layer dies with it; when ProDOS becomes a type
(Phase 3), register both under a tag shaped by the actual `mount -t` consumer.
The sentence to overturn is `vfsops.h:33`, "1.8b registers ufs.mod's vfsops as
a VT_FST vtable".

**2.  The bank risk is inverted.**  "ufs.mod is nearly full at ~51KB" is the
PRE-SPLIT number, quoted in `ufs.s:87-96` as the reason the 1.13a probe split
happened.  Shipping module banks have room.  The tight bank is the PROBE
module: with `kernel.ufswprobe = 1`, ufsprobe.mod is **64,295 bytes of
65,536** (`ufs_devprobe.c:12-13`), and its own header says "the next case of
any size does not link whichever file it goes in."  **The vettability budget
is more constrained than the code budget.**  Price a fifth gate split or a
second probe module BEFORE writing new cases, not when the link fails.

**3.  Cosmetic.**  `main.s:2780`'s guard comment says the kernel must end
before `$028000`; `FGX_DATA` is `$02ED70` (`include/kernel.s:121`).  The
`ERR *-1/FGX_DATA` guard is symbolic and live; only the comment is stale.

## What the breakage relaxation buys

The maintainer, 2026-08-21: earlier rulings are overturnable, and "it's ok to have some
temporary breakage as long as we can still run tests necessary to vet the
changes."

**The hard constraint is VETTABILITY, not workingness.**  A step whose
breakage is invisible to both test surfaces is the thing to avoid.  The two
surfaces:

  * `tools/gate.sh` -- 34 MAME-driven suite tests (`gate.sh:423`), ~45s.
    Boots a real machine and drives a shell.  Sees the syscall layer, the
    kernel-asm marshalling, and userland.
  * `tools/tryprobe.sh` -- five kernel-resident C probe gates asserting
    against real UFS volumes built by the host `fgxfs`.  Sees the VFS
    internals.  Cannot see kernel-asm marshalling or caller-bank discipline.

What the relaxation does NOT buy: a shortcut to the root swap.  The bulk of
Phase 2 is boot-chain and image-build work (stage1 in one sector, stage2
reading UFS, `disk_src` staging moved to `fgxfs`, ~90 manifests) and none of
it shrinks.  Root-swap-first would darken BOTH surfaces at once, which is
exactly what the relaxation's own condition rules out.

What it DOES buy is one thing, and it is the plan's centre: **the descriptor
conversion lands as a single increment** instead of being smeared across
releases with `f_ops` and `FCB_Flags` both authoritative -- the dual-authority
state `file.h:41-44` warns about.

It also lets the `/ldev` consumers be swept back in ONE pass rather than one
name at a time, overturning the schedule stated at `path.s:123`.

The `/ldev` rename and the hook fall-through (branch `feat/ldev-rename`) are
NOT scaffolding to be regretted: they are what makes a real /dev mountable
while `/ldev/console`, the VCs and staged rc references keep working.  Only
their retirement schedule changes.

## The increments

Critical path: I1 -> I2 -> I3 -> I4 -> Phase 2.

### I1 -- `vnops` and the syscall-shaped C, with no caller

Write `struct fileops vnops` and a `vfs_syscalls.c` subset (open/close/read/
write/lseek bodies taking kernel-marshalled arguments) into vfs.mod.  Nothing
in the kernel calls it yet.  `file.h:44` is where `vnops` was always going to
go.

**Red signal:** new cases in `file_probe.c` (or a new `vnops_probe.c`) driving
`falloc -> vn_open -> (*f_ops->fo_read)() -> closef` against the fgxfs-built
scratch volume.  The fileops indirection is the new thing under test, so at
least one mutation-checked case must go red when `fo_read` is routed to the
wrong vector.  The 34 suite tests stay green because the code is inert.

**Invisible-breakage risk:** none; nothing is reachable.

**Bank watch:** must fit vfs.mod's remaining space or spill to a new module
bank (ufsprobe set that precedent; module-to-module shims are generated now).
Decide which probe config the new cases ride in BEFORE writing them --
see CORRECTED item 2.

### I2 -- wholesale descriptor conversion  (the maintainer ruled YES, 2026-08-21)

Per-task fd table maps fd to `struct file`.  `falloc`/`ufalloc`/`getf`/`closef`
(built at 1.2c) go live.  The nine `_Fcb_ClassifyFlags` sites collapse into
`f_ops` dispatch.  Legacy types -- console, ProDOS file, pipe, socket, chardev
-- get a legacy `fileops` wrapping the existing arms, with `f_data = FCB`.

This is not the halfway shim the campaign's Seam 3 rejected.  It is Reno's own
architecture: fileops selects vnode-vs-socket, and FGX adds
vnode-vs-FCB-vs-pipe.  It is also what the 2026-08-09 RESOLVED pipe decision
already blessed ("FGX's existing pipe table behind an ops vector is where
4.4BSD itself ended up").  The FCB does not retire here; it demotes to
ProDOS's per-open private data and dies with the FOP layer in Phase 3.

**No VFS routing in this increment.**  It is pure re-plumbing of a layer that
already has total suite coverage, isolated so that a red names the descriptor
layer and nothing else.

**Red signal:** all 34 suite tests.  dupfile, pipegrow, sockleak, sockemfile,
selwild, coninv, softexec and ptykey are precisely this layer.

**Expected reds that are CORRECT and must be triaged, not reverted:**
fork-shared file offsets via `f_count` are a real semantic change -- today's
FCB is per-fd.  Some tests may go red for the right reason.

**Must survive verbatim:** the O_CREAT/O_EXCL/O_APPEND ladder at
`syscall.s:4150-4210`, including the mkstemp EEXIST behaviour.

**Invisible spot:** `struct file` leaks on error paths.  `sockemfile` and
`sockleak` cover the socket arm; add one `file_probe` case that exhausts and
drains the file table through the syscall-shaped entry points.

### I3 -- mount UFS at /dev: the inward seam, built with its customer

Boot mounts the fgxfs-built dev volume, replacing the staged
`disk_src/dev/PROOF` directory.  `_Sys_Open` checks the mount prefix **at the
syscall boundary, before `Path_Resolve`**: on a hit it JSLs into vfs.mod
(falloc, namei rooted at that mount's root vnode, `vn_open`,
`f_ops = &vnops`); on a miss the legacy path is unchanged.  Read/write/close
on the resulting fd already work through I2's dispatch.

Routing at the syscall boundary rather than inside `path.s` is load-bearing
twice: it keeps `fs.s`/`prodos.s` sleep-free so `check_fs_sleep_invariant`
retains its meaning, and it makes Phase 2's root swap "change which arm is the
default" instead of new machinery.

**Red signal: smoke itself crosses the seam.**  `/bin/sh` opens `/dev/null` at
startup from pristine vendored source (`vendor/2.11BSD/usr/bin/sh/msg.c:65`),
so every one of the 34 tests exercises open-through-namei-through-`spec_*` the
moment this lands.  `ufsdevprobe` stays green underneath.

**Add one suite case using a STATEFUL device** plus `ls /dev` and a
redirection.  `ufs_devprobe.c`'s header states that `/dev/null` cannot convict
`spec_open`'s dispatch -- a `/dev/null`-only probe certifies an arm that works
for one device.

**This is the increment where probe-invisible breakage lives.**  The
kernel-asm marshalling -- caller-bank path copy, DBR discipline, argument
widths -- is exactly what kernel-resident C probes cannot exercise.  The suite
is the only witness.  Keep the increment small, and land the seam and its
first customer in the SAME commit; `main.s:2158` already says the seam must be
"shaped by that customer".

### I4 -- deletions

The /dev branch of the prefix hook is now unreachable at all three inline
sites (`path.s`, `fs.s` Fs_Open, `fs.s` Fs_Stat/spawn).  Delete it.  Sweep the
remaining `/ldev` consumers onto real device nodes in ONE pass -- this
overturns the one-name-at-a-time schedule at `path.s:123`, which the breakage
relaxation makes unnecessary -- then delete the hook entirely, along with
`FCB_FstIdx`, `MT_FstIdx` and the `FST_IDX_*` vestiges.

Six device families to land as real nodes: /dev/null first (it fixes
`/bin/sh` and `/bin/tcsh` for free, since they hardcode the string); the ptys
(ptyp0/ttyp0/ptyp1/ttyp1); the VCs (ttyv1/ttyv2); /dev/console; /dev/tty (the
INDIRECT driver, apple/fgx#151); and the module-registered /dev/bpf0 and
/dev/tty01.  Eight suite-covered tools open these by path -- winsz, fractal,
nottykey, vcclose, scrnhold, ttysprobe, vcstate, vcwrite -- so each has a test
that will say so.

**Red signal:** the suite.  Each deletion that was actually load-bearing goes
red loudly.

### Phase 2 -- unchanged ordering, one addition

Order stands: on-target fsck (2.1), stage1/stage2, build system, root swap,
/dev folds into the root filesystem.

**Addition: build the `smoke_ufs` boot manifest FIRST**, before the shipping
image is touched, so the UFS boot chain has a red/green signal while the main
suite still runs against the ProDOS image.  That is what keeps 2.2-2.4
vettable through the dark window.

The maintainer ruled (D4, 2026-08-21) that the suite may stay red "as long as it needs
to really".  A dual-image period is therefore a convenience rather than a
requirement -- but `smoke_ufs` is not optional, because it is the only thing
that makes the window vettable at all, and the relaxation is conditioned on
being able to vet.

### Phase 3 -- ProDOS as a type  (the maintainer ruled D3, 2026-08-21)

**FGX will always need a ProDOS FST.**  It is not deleted.  What changed is
priority: it is "not immediately critical as long as the OS has been
completely converted to UFS", so it comes AFTER the root swap and is off the
critical path.

ProDOS gets `prodos_vfsops` + `prodos_vnodeops` and becomes an ordinary
mountable type (`mount -t prodos`, campaign goal 4).  Only then do the FOP
table, `fst_dispatch.s`, `_fst_ops_save`, the legacy fileops arm and the FCB
retire.  The campaign's own O1 analysis prices this honestly: per-component
lookup against a parent vnode must be written new into 5,378 lines of
assembly, plus the mutable key-block identity problem.  Read-only first.

### Off the critical path, can proceed in parallel

On-target fsck (2.1), disklabel work, `fgxfs` staging of the full root image,
and preparation of the `/ldev` consumer sweep are host-side or independent.

## Risks this plan adds or reprices

**R1.  Syscall-layer statics across the new sleeps.  UNPRICED UNTIL NOW, and
the sharpest item here.**  The campaign risk table prices the FS layer's
singletons and closes the risk by keeping `sleep` out of `fs.s` and
`prodos.s`.  I3 makes `_Sys_Open` ITSELF sleep for the first time -- inode
locks, buffer locks -- and `_Sys_PathBuf`, `_Sys_OpenFlags` and `_Sys_OpenFd`
are shared kernel statics.  That is the #41 / #100 / #105 class exactly, and
`syscall.s:4230-4240`'s restart-args note already records that these cells are
not in swtch's carryover.

Failure mode: cross-process path corruption that NO single-process test can
produce.  `check_dp_sleep_safety` guards DP cells; whether it sees these
ABSOLUTE statics needs checking, and extending it is part of I3.  The fix is
#105's: capture into per-task storage (the per-pid nameidata slots from 1.2b)
before the first possible sleep.

**R2.  Probe-bank headroom is the vettability budget, and it is nearly
spent.**  See CORRECTED item 2.  Decide the split before writing I1's and
I3's cases.

**R3.  The inward seam's banking traps.**  The kernel-to-module-C call is new
machinery in the #178 class (an indirect call carrying the callee's bank as
DBR), on top of the `--kernel-bank` bare-offset history and the fact that VOP
dispatch has no reverse shim.  Mitigations exist -- shims are generated and
the generator is validated against the 13 hand-written ones instruction for
instruction; the VFSCORE convention documents DBR ownership.  The exposure is
the window DURING I3, which is the argument for keeping that increment small.

**R4.  CORRECTED TWICE, AND THE SECOND CORRECTION IS THE IMPORTANT ONE: THE
KERNEL IS NOT ONE BANK AND IS NOT SHORT OF ROOM.**  Measured, both banks, same
checker on the same build:

    kernel 56696 B of 57968 ( 1272 free)      <- the CORE bank
    far    15822 B of 60480 (44658 free)      <- the FAR bank

Everything below about the core bank being tight is TRUE AND NEARLY
IRRELEVANT, and reading it as "the kernel is almost out of room" -- which this
plan did -- is what made a placement question look like a budget crisis.  The
core bank is where the syscall dispatcher and the FS layer live and it has
1,272 bytes.  The FAR bank is where KERNEL C lives (fcc's runtime, its direct
page, its trap; see src/kernel/far/) and it has 44,658.

WHICH BANK A THING GOES IN IS A DESIGN QUESTION, NOT AN ACCOUNTING ONE.  The
far bank is not overflow space for whatever the core cannot fit: it is where
the C runtime is established, so code that CALLS C belongs there and code the
syscall path enters directly belongs in core.  1.7d's seam is the worked
example -- it was built in the core bank first, in assembly, and the shims it
calls document their own precondition as "entered from C, which left DBR on
our bank".  Core assembly does not satisfy that.  The far bank does, natively.

So I2/I3 should be budgeted against the bank each piece actually belongs in,
and the paragraph below stands only for the core-resident parts.

**The original entry, kept because the first figure was wrong in the dangerous
direction:**  MEASURED by `tools/check_kernel_ceiling.py`, which
runs on EVERY build and is the authority:

    kernel 56036 B of 57968 (1932 free)

The region is `FGX_CODE $020B00 .. FGX_DATA $02ED70` = $E270 = 57,968 bytes,
checked against the actual binary.  **1,932 FREE, NOT 5,361.**

The 5,361 figure came from a handoff that "corrected" the roadmap's 1,932 by
subtracting an address ($02D87F) that is the end of a SEGMENT rather than of
the image.  The roadmap was right and the correction was not; the first draft
of this plan repeated the error.  THREE different numbers for one quantity
have been in circulation in two days -- so measure it, never quote it.

That is roughly a third of the headroom this plan was sequenced against, and
both remaining risky increments spend it: I2's fd table and `f_ops` dispatch,
I3's router and its marshalling, all kernel-bank resident.  **Budget I2 and I3
against 1,932 bytes before writing either.**  The `ERR *-1/FGX_DATA` guard
(`main.s:2784`) turns an overrun into a build failure rather than a boot
failure, so this is loud -- but it is loud at the END of an increment, which
is the wrong time to find out.

The offsetting income is real and arrives LATE: the 28 `_Fst_Dispatch` sites,
`fst_dispatch.s`, `_fst_ops_save` and the per-byte read/write ladders become
deletable at Phase 3, not at I2.  If I2 does not fit, the lever is moving
kernel statics out of the `FGX_DATA` region to raise the ceiling -- the
checker's own error text names it, and `docs/history/plans/far-kernel-bank.md` documents it.
That is a placement change rather than a design one, and it is how NPROC's
wall was moved before.

**R5.  Repriced DOWN.**  The campaign's "data-structure memory" and
module-bank worries predate the 1.13a split and are no longer tight on the
ufs side.  The Phase-1 "13 deliverables, nothing to test until the end" risk
is dead: eleven are landed with five probe gates green.  Remaining campaign
risk is concentrated in exactly two places -- the descriptor conversion (I2)
and the boot chain (Phase 2) -- and both now have named test surfaces that
can convict them.

## Decisions of record

| Id | Question | Ruling |
|---|---|---|
| D1 | Wholesale descriptor conversion at I2, or an `FCB_FL_VNODE` arm? | **Wholesale** (the maintainer, 2026-08-21).  The alternative is the convert-twice path Seam 3 prices as the worst outcome. |
| D2 | Does Phase 2's ordering change under breakage tolerance? | **No.**  Root-swap-first darkens both surfaces at once. |
| D3 | Does `mount -t prodos` still stand? | **Yes, always needed** -- but off the critical path, after full UFS conversion (the maintainer, 2026-08-21). |
| D4 | How long may the suite stay red? | **As long as it needs to** (the maintainer, 2026-08-21).  `smoke_ufs` first is still required, being the signal the relaxation is conditioned on. |

Settled by evidence, no ruling needed: do not build `_FstTable`; do not
register ufs's vfsops under `VT_FST` and do not mint a replacement tag yet
(overturns `vfsops.h:33`); route at the syscall boundary, not inside `path.s`;
sweep `/ldev` in one pass (overturns `path.s:123`).

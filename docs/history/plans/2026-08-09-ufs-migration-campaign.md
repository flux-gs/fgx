# FGX: migrating from ProDOS to the 2.11BSD filesystem

High-level campaign plan.  The maintainer scoped this 2026-08-09 after eight BSD-parity
issues traced back to one root cause: ProDOS has no inodes, no permissions and
no device nodes, so the kernel keeps growing BSD mechanisms the filesystem
cannot express.  Background and the full gap list:
`docs/history/RESUME-2026-08-09-bsd-parity-and-fs-scope.md`.

## Design goals (the maintainer, verbatim intent)

1. Remove all ProDOS dependencies from FGX.
2. Match v7/2.11BSD structure closely enough that an FGX volume mounts on a
   2.11BSD PDP-11/70, and a 2.11BSD volume mounts on FGX.
3. Support external filesystem types (`mount -t prodos`, `mount -t fat`),
   consistent with BSD.
4. Ship `mount -t prodos` with read/write support.

Goals 1 and 4 are not in tension: ProDOS stops being *the* filesystem and
becomes *a* loadable type, required neither for boot nor for root.

## Decisions taken

| Decision | Choice |
|---|---|
| FS core language | C via fcc, near-verbatim BSD source; inline asm only where performance or stack depth forces it |
| VFS architecture | 4.3BSD-Reno `kern/vfs_*.c` + `vfs_bio.c` + `spec_vnops.c`, sized down |
| Governing principle | keep the BSD design pattern unless there is a clear and present reason not to; optimise for BSD compatibility at campaign END |
| On-disk format | 2.11BSD (free-list superblock, 64-byte dinode, 16-bit ino_t) |
| Cutover | UFS is the VFS's FIRST client and its ROOT; the legacy path runs beside it until retired |
| v1 scope | device nodes + mknod, permissions in namei, unlink-while-open + block reclaim, fsck |

## The two-source split

The single most important structural decision.  **Architecture from Reno,
format from 2.11BSD.**

```
  kern/vfs_syscalls.c   <- Reno, near-verbatim
  kern/vfs_lookup.c     <- Reno   (namei)
  kern/vfs_subr.c       <- Reno   (vget/vput/vgone/checkalias)
  kern/vfs_vnops.c      <- Reno   (file-table glue)
  kern/vfs_cache.c      <- Reno   (namei cache)
  kern/vfs_bio.c        <- Reno   (buffer cache -- VNODE-KEYED, see the bio seam)
  kern/dead_vnops.c     <- Reno   (vgone/vclean need it)
  kern/vfs_conf.c       <- Reno   (vfssw[] == mount -t)
  kern/spec_vnops.c     <- Reno   (specfs; closes #76 and #74)
  --------------------------- the seam (ours) ---------------------------
  ufs/ufs_lookup.c      <- Reno SHAPE, 2.11BSD dirents
  ufs/ufs_inode.c       <- 2.11BSD bodies on Reno signatures
  ufs/ufs_alloc.c       <- 2.11BSD free list, NOT FFS cylinder groups
  ufs/ufs_bmap.c        <- 2.11BSD, 4 direct + 3 indirect
  on-disk dinode        <- 2.11BSD, 64 bytes, PDP byte order
```

Why not take Reno's `ufs/` wholesale: **Reno's ufs is FFS.**  Cylinder groups,
a fragment allocator, `ufs_tables.c` fragment tables, a 1,073-line
`ufs_alloc.c`, 128-byte dinodes, 32-bit `ino_t`.  A 2.11BSD 11/70 cannot mount
it (goal 2 fails outright) and it is sized for a VAX.

**The directory formats are the same FAMILY but are NOT byte-compatible.**
An earlier draft of this plan claimed they were identical and used that to
argue `ufs_lookup.c` crosses over nearly intact.  That is false:

| | 2.11BSD | Reno |
|---|---|---|
| `d_ino` | `ino_t`, 2 bytes | `u_long`, 4 bytes |
| `MAXNAMLEN` | 63 | 255 |
| `DIRSIZ` | 6-byte header, header+name rounded together | 8-byte header, name rounded separately |

Same name, different on-disk record length, `d_namlen` at a different offset,
and a different `struct dirtemplate` for mkdir's `.`/`..` image.  Since
`ufs_lookup.c` consists almost entirely of `DIRSIZ`/slot-fit/reclen arithmetic
-- the free-slot search, `ufs_direnter`'s reclen math, `ufs_dirremove`'s reclen
merge -- **every one of those computations changes.**  Treating the port as
mechanical produces directories 2.11BSD's fsck will reject, failing goal 2 at
precisely the point this plan once called cheapest.

Reno's `ufs_lookup.c` is also not FFS-free: it includes FFS's `fs.h`, calls
`blkatoff()`, and uses the fragment-aware two-argument `lblkno(fs, off)` and
`blksize(fs, ip, lbn)` macros, none of which exist in 2.11BSD (whose `lblkno`
takes one argument).

**A field-name firewall is mandatory.**  `fs_fsize` means the FRAGMENT SIZE in
Reno and the TOTAL VOLUME SIZE IN BLOCKS in 2.11BSD (`h/fs.h`).  Code ported
between the two compiles clean and silently does something else.  The port must
rename 2.11BSD's field on the way in so the collision cannot occur.

Why it is still the main risk: **both halves are proven code, but the joint
between them has never existed anywhere.**  2.11BSD's `ufs_*` functions are
written against `struct inode` plus u-area globals (`u.u_error`, `u.u_base`);
Reno's want vnode/uio/ucred arguments.  The conversion is mechanical but it is
ours to get right, function by function, with both sources open.

## The device model: no synthesized /dev

**Decision (the maintainer, 2026-08-09): there is no synthesized `/dev`.  `/dev`
operates exactly as it does on BSD** -- real `IFCHR`/`IFBLK` inodes on a real
filesystem, created by `mknod`, opened by path like any other file.  An earlier
draft proposed keeping `/dev` synthesized through phase 1 so specfs could land
early; that is dropped.

BSD splits the device world in two, and the split is what makes this work:

- **`cdevsw[]`/`bdevsw[]`** -- a compiled-in table indexed by major number.
  Available from boot, before any filesystem is mounted.  The console and the
  boot block device work through it with no `/dev` in existence.
- **`/dev` nodes** -- ordinary inodes whose data is a `(major, minor)` pair.
  They exist only so devices can be *named and opened by path*, and so
  permissions apply to them.

So "no synthesized `/dev`" does not mean the kernel cannot reach a device
before mount.  It means there is no fake namespace layer pretending to be a
filesystem.  `cdevsw` is phase 1; device *nodes* arrive with the first
filesystem that has inodes.

**Consequences, stated plainly:**

1. **specfs cannot precede UFS.**  Real device nodes need real inodes, and
   ProDOS has none.  `spec_vnops` + `checkalias` move into the UFS phase.
2. **#76 waits.**  The plan previously closed the chardev-Close granularity bug
   early via synthesized-`/dev` specfs with no format change.  That option is
   gone.  The upside: when it lands it is the CORRECT fix (`checkalias` +
   `spec_close`'s `vcount`) rather than a third hand-rolled device-open counter
   beside `_Pty_MaybeReset`'s flag pair and #72's proposed `TTY_Flags`.
3. **This reinforces O1.**  If the VFS's first client cannot be the thing that
   delivers `/dev`, building phase 1 on ProDOS buys even less than it did.
4. **A real `/dev` is available before the root swap.**  Mount UFS *at `/dev`*
   while root is still ProDOS.  Real nodes, real filesystem, real specfs, with
   the root swap still ahead.  Needs only VFS + UFS + `mount(2)`, all of which
   the UFS phase delivers anyway.  This is the recommended way to get `/dev`
   and #76 early without reintroducing anything synthetic.

## The three seams, and how each is decided

**Governing principle (2026-08-09): keep the BSD design pattern unless there is
a clear and present reason not to.  The measure is how much BSD compatibility
FGX has when the campaign ENDS, not how little work it is midway.**  Cost and
embeddedness are not reasons; they are prices.

The plan originally described ONE seam -- Reno above, 2.11BSD below, cutting
through `ufs/`.  The second review established there are three, and the other
two cut horizontally through files this plan calls near-verbatim.

**Seam 1: the filesystem (`ufs/`).**  Reno's shape, 2.11BSD's format and
allocator.  Unchanged.  Note that 2.11BSD's own `sys/ufs_namei.c` is already
4.3-shape lookup over 2.11 dirents, so the directory layer has a debugged
reference implementation of exactly this joint -- an earlier draft's claim that
"the joint has never existed anywhere" is false for the directory code, and its
"rewrite rather than a copy" framing was scare-costing.  Realistic survival of
`ufs_lookup.c` once the headers swap: ~75-85%.

**Seam 2: the buffer cache.  DECIDED: take Reno's `vfs_bio.c`, vnode-keyed.**
Both candidates are BSD -- 2.11BSD's device-keyed cache is simply the older
design.  Reno's is architecture, and architecture comes from Reno.  Decisively:
vnode-keying is where BSD went and stayed, so a device-keyed cache means
hand-editing every buffer call site in the kern tier now AND on every future
BSD import -- a permanent compatibility tax, which the governing principle
rules out.  The objection that `vfs_bio.c` depends on `struct vnode` is an
ordering fact, not a reason: the vnode structures simply land first.

**Seam 3: process, credentials and the file table.  DECIDED: adopt BSD's.**
Reno's VFS assumes a per-process `struct nameidata` (`u.u_nd`), refcounted
`ucred` (`crhold`/`crfree`/`nddup`), `struct file` with `f_data`/`f_offset`/
`f_type` behind `u.u_ofile[]`, plus `u.u_cmask` and `u.u_rlimit`.  FGX has a
38-byte FCB with pipes, sockets and chardevs riding inside it through
`FstPriv` overlays.  Converting halfway means every future BSD import fights
the FCB forever; converting properly also makes pipes and sockets fall out as
ordinary `DTYPE_*` file-table entries instead of needing invention.
**This must land EARLY** -- `vfs_vnops.c` IS the file-table glue, so building
the VFS over an unconverted FCB means converting twice.

## Partitioning: the full BSD disklabel

**Decision (2026-08-09): FGX implements the real BSD disklabel, for parity --
specifically 2.11BSD's, NOT 4.4BSD's.**  They are different on-disk
structures.  `h/disklabel.h:58-77` says so outright: 2.11 narrowed the
geometry fields to `u_short` and the partition entries to 12 bytes because "D
space is precious in the 2.11 kernel".  Writing a 4.4-shaped all-`long` label
produces something a real 2.11 system rejects -- goal 2 would fail at the
label before it failed anywhere else.
Today a SmartPort unit simply *is* a volume and there is no partitioning at
all; `FS_MAX_MOUNTS` is 14, a number inherited from ProDOS 8's DEVLST cap
rather than chosen.

The mechanism, from `h/disklabel.h` and `sys/ufs_disksubr.c`:

| | |
|---|---|
| Label location | `LABELSECTOR` 1, `LABELOFFSET` 0 |
| Magic | `0x82564557`, in BOTH `d_magic` and `d_magic2` |
| Integrity | `dkcksum()` over the label |
| Partitions | `MAXPARTITIONS` 8, `a`-`h`, each an (offset, size) in sectors |
| Read size | `lp->d_secsize` (the source notes it should probably be wired to 512) |

Two rules come straight from the source and both constrain us:

**Partition `a` must start at sector 0**, because `a` is what the label is
read through (`ra.c`: "partition 0 ('a') is used to read the label.
Therefore 'a' must start at the beginning of the disk!").

**An unlabeled disk is not an error -- `a` spans the whole unit.**  The driver
installs a default label, attempts `readdisklabel()`, and on failure keeps the
default, logging `no disk label`.  This is BSD's own behaviour, not a
concession, and it is what makes goal 4 free: a ProDOS-formatted SmartPort
unit carries no BSD magic, so it presents as a single whole-unit partition and
`mount -t prodos` works with no special-casing anywhere.

### Consequences

1. **Stage-1's budget drops to ONE sector.**  An earlier draft gave stage-1
   the whole 1024-byte boot area -- 512 auto-loaded by the ROM plus 512 pulled
   through the SmartPort dispatcher.  **Sector 1 is the disklabel**, so that
   second half is spoken for.  Stage-1 gets sector 0 alone, and the rest of the
   loader must come from a block range `mkfs` reserves or from the filesystem
   itself.  The "fallback" option under stage-1 is therefore promoted to the
   primary plan.
   ProDOS boot still works: the ROM only requires byte 0 of block 0 to be
   `$01`, which says nothing about sector 1.
2. **Minor numbers encode the partition.**  BSD packs
   `minor = unit * 8 + partition`.  Adopt it verbatim -- and decide it *before*
   phase 1.6, because that is where `cdevsw`/`bdevsw` and major/minor land and
   the encoding is baked in from that point on.
3. **32-bit block numbers become a prerequisite, not a nicety.**  Deliverable
   1.0 already widens `blkcache.s`'s 16-bit block key, but partition offsets on
   a large device are precisely the arithmetic that overflows a 16-bit block
   number first.  Partitioning cannot land before it.
4. **`disklabel(8)` joins the userland set**, alongside `mkfs`, `fsck`,
   `mount`, `umount` and `mknod`.

Not in scope: the Apple Partition Map that GS/OS uses on SCSI.  Recognising it
would be a separate reader, and nothing in this campaign needs it.

## On-disk format: the contract

Taken from `examples/2.11BSD/usr/sys/h/{fs.h,inode.h,dir.h,param.h}`.

| | |
|---|---|
| Device block | 512 bytes (SmartPort native) |
| Filesystem block | 1024 bytes; `fsbtodb(b) == b<<1`, already a shift |
| Block 0 | boot block, `BBSIZE == 1024` (two SmartPort blocks) |
| Block 1 | superblock (`SUPERB`) |
| Root inode | 2 (`ROOTINO`) |
| dinode | 64 bytes, 16 per fs block (`INOPB`) |
| Block pointers | 4 direct + 3 indirect, 4-byte `daddr_t`, 256 per indirect |
| Free space | superblock free list (`fs_nfree`/`fs_free[50]`) + `fblk` chain |
| Free inodes | superblock cache (`fs_ninode`/`fs_inode[100]`) + i-list scan |
| Names | up to 63 chars, case SENSITIVE, variable-length dirents |
| ino_t | `u_short`, so 65535 inodes per volume |
| Path max | 256 (`MAXPATHLEN`) |

Two findings that make this work:

**Block 0 being the boot block is a gift, not a compromise.**  The IIgs ROM
loads block 0 to `$0800` and enters at `$0801`.  2.11BSD reserves exactly that
block for exactly that purpose.  The boot contract and the filesystem layout
already agree; nothing has to be bent.

**fcc's struct layout is PDP-11 identical.**  Measured, not assumed: for
`struct { unsigned short a; long b; unsigned short c; long d; char e[7]; long
f; }` fcc places `b` at offset 2 (not 4) and reports `sizeof` 24 -- the exact
PDP-11 result.  Field OFFSETS therefore agree with 2.11BSD without any padding
fixups.  This has to be locked with a regression fixture, because a future fcc
alignment change would silently corrupt every volume.

**Offsets agreeing is not the same as values agreeing.**  MEASURED on a real
2.11BSD PDP-11/70 (kernel #18) on 2026-08-09, not inferred: the long
`0x01020304` stores as the bytes `02 01 04 03`, i.e. **high word first,
little-endian within each word.**  The same value on the 65816 is
`04 03 02 01`, so the conversion is exactly a **16-bit half-swap** -- cheap,
but binding for goal 2.  A `short` stores as `02 01`, confirming
little-endian within a word.

An earlier draft claimed both "direct overlay" and "half-swap everywhere",
which cannot both be true.  The resolution:

- **16-bit fields overlay directly** -- `di_mode`, `di_nlink`, `di_uid`,
  `di_gid`, `di_flags`, `d_ino`, `d_reclen`, `d_namlen`, `fs_isize`,
  `fs_ninode`.  That is most of the surface.
- **32-bit fields go through accessor macros** that half-swap on read and on
  write: `di_size`, `di_addr[7]`, all three timestamps, `fs_fsize`,
  `fs_free[50]`, `fs_time`, `fs_tfree`, and **every indirect block, which is
  256 raw `daddr_t` and nothing else**.

The swap must NOT happen in place inside cache buffers: `blkcache.s:10` states
the invariant that a valid entry is byte-identical to the block on disk, and an
in-place swap meeting write-back corrupts the volume.  Accessors are the only
safe placement.

### Measured layout (2.11BSD PDP-11/70, kernel #18, 2026-08-09)

Every number below came off the real machine, not from reading headers.

```
DEV_BSIZE=1024  MAXBSIZE=1024  INOPB=16  NINDIR=256
MAXNAMLEN=63    DIRBLKSIZ=512  NDADDR=4  NIADDR=3
NICFREE=50      NICINOD=100    ROOTINO=2 SUPERB=1
short=2 int=2 long=4 ptr=2
daddr_t=4 ino_t=2 time_t=4 off_t=4 dev_t=2

sizeof: dinode=64   fs=446   direct=70

dinode  mode=0 nlink=2 uid=4 gid=6 size=8 addr=12
        reserved=40 flags=50 atime=52 mtime=56 ctime=60
fs      isize=0 fsize=2 nfree=6 free=8 ninode=208 inode=210
        flock=410 fmod=411 ilock=412 ronly=413 time=414
        tfree=418 tinode=422 fsmnt=428 lasti=440 nbehind=442 flags=444
direct  ino=0 reclen=2 namlen=4 name=6
```

Three of these are load-bearing:

- **`fs_fsize` sits at offset 2, not 4.**  Longs are NOT 4-aligned, which is
  the fact the whole direct-overlay approach rests on -- and it matches what
  fcc does.  `struct fs` packs contiguously to exactly 446 with no interior
  padding anywhere, which is the cross-check.
- **`sizeof(struct dinode) == 64`** with `size` at 8, `addr` at 12, `ctime` at
  60 -- byte-identical to the struct in fcc's new conformance fixture.
- **`sizeof(struct direct) == 70`**, `d_name` at 6.  A 6-byte header, against
  Reno's 8.  This is the incompatibility that makes `ufs_lookup.c`'s reclen
  arithmetic a rewrite rather than a copy, now confirmed from both sides.

## What survives, what dies

**Survives and gets reused:**

- `src/drivers/block/` -- `block.s` (1,348) and `blkcache.s` (1,301), but
  **not as-is.**  An earlier draft called the cache ready to back
  `bread`/`bwrite`.  It is not: it is a WRITE-THROUGH READ cache.  Zero
  occurrences of "dirty" in the file; the stated invariant (`blkcache.s:10`) is
  that a valid entry is byte-identical to disk; there is no write-back path and
  no sleep-based buffer locking.  2.11BSD's UFS calls `bdwrite` constantly --
  directory updates, inode blocks, free-list churn.  Block keys are also 16-bit
  (`blkcache.s:58,122`), a ~32 MB ceiling against 2.11BSD's 32-bit `daddr_t`.
  **Adding `bdwrite`/`brelse`/buffer locking and widening the key is a named
  deliverable with a phase number (1.0), not a free inheritance.**
- The module loader.  A module gets its own bank via `Bank_Alloc`, so the VFS
  and each filesystem type get room without touching the ~3.9 KB free in the
  kernel bank.
- `src/modules/prodos/prodos.s` (5,378) -- retargeted, not discarded.  It
  becomes the `prodos` vfsops/vnodeops implementation and delivers goal 4.

**Dies or is absorbed:**

- `src/kernel/fst_dispatch.s` -- the single-slot `VT_FST` vtable.  One
  registered type at a time, dispatched through a self-modifying JSL cell.
  `vfssw[]` replaces it.
- The 22 path-based `FOP_*` slots (`include/fst.s`).  Path-oriented ops cannot
  express a mount point inside another filesystem's tree except by string
  prefix matching, which is the exact divergence this campaign exists to
  remove.  `FOP_Lookup` is currently `ENOSYS`, which is the tell.
- `src/drivers/fs/inode.s` -- the 16-slot, 8-byte in-core inode keyed on
  ProDOS key block.  Replaced by real vnodes.
- ProDOS-shaped `FCB_FstPriv` overlays (key block, storage type,
  seedling/sapling/tree buffers).

## Syscall surface that does not exist yet

Present today: `stat`, `fstat`, `mkdir`, `rmdir`, `unlink`, `rename`, `utime`,
`ftruncate`, `fsync`, `sync`, `dup`, `dup2`, `ioctl`, `getfsstat`.

**Missing entirely and required:** `mount`, `unmount`, `mknod`, `chmod`,
`fchmod`, `chown`, `fchown`, `link`, `symlink`, `readlink`, `lstat`, `access`,
`umask`, `truncate`.  Reno's `vfs_syscalls.c` implements all of them; the work
is wiring FGX's dispatcher entries to those bodies.

## Phases

Each phase ends bootable, suite-green and releasable.  Gates are stated as
measurements, not as opinions.

**Every phase ships at least one test that goes RED without that phase's
machinery.**  Not negotiable, and not satisfied by the existing suite: the 86
manifests test only behaviour reachable today, so none of them exercises
per-component lookup, a mount inside another filesystem, alias accounting, or
inactive-time reclaim.  A phase whose only evidence is "suite still green" has
produced a regression check, not a gate.

**Phases 1 and 2 are INVERTED from the first draft** (the maintainer, 2026-08-09).  The
VFS's first client is UFS, not ProDOS.  Rationale under O1.

### Phase 0 -- de-risk, no format change

Nothing on disk changes.  The point is to kill the campaign cheaply if one of
its premises is false.

### Where kernel C actually lives (corrected 2026-08-09)

An earlier draft said the VFS gets "a module bank via `Bank_Alloc`".  That is
the `modload.conf` path, and it **cannot host a filesystem**: runtime module
loading requires a live filesystem to load the module that implements the
filesystem.  FGX already solves this for ProDOS and the plan should copy it.

Three mechanisms exist, and they are not interchangeable:

| mechanism | loads via | current users |
|---|---|---|
| `preload.conf` | stage2 pre-stages the bank BEFORE the kernel runs | `PRODOS` |
| `modload.conf` | runtime load; needs a live filesystem | serial, bpf, net |
| far kernel bank | second statically-linked image, fixed export slots (`include/kfar.s`) | console, sound, clock, BRAM |

So: **filesystem types (ufs, prodos) are PRELOADED module banks**, exactly as
`prodos.mod` is today -- stage2 reads them with its own reader before the
kernel starts.  **VFS core** (vfs_subr, namei, vfs_syscalls, vfs_bio) is core
kernel reached by syscalls, so it belongs in the core bank or the far kernel
bank, not a module.

### The kernel/C error convention: BSD's answer is NOT a compiler feature

The open question was whether fcc should grow a carry-return attribute so a C
function could speak the kernel's `C=1 success / A=errno` convention natively,
or whether every converted routine needs a hand-written thunk.  Asked of the
oracle, the answer is neither.

**2.11BSD sets the carry bit in exactly ONE place** -- the syscall return path
in `pdp/trap.c:359-374`:

```c
switch (u.u_error) {
  case 0:           ps &= ~PSL_C;  r0 = u.u_r.r_val1;  r1 = u.u_r.r_val2; break;
  case ERESTART:    pc = opc;      break;
  case EJUSTRETURN: break;
  default:          ps |= PSL_C;   r0 = u.u_error;     break;
}
```

Kernel C functions never touch a carry flag.  They write `u.u_error` and, on
success, `u.u_r.r_val1` (and `r_val2`, which `fork`, `pipe` and `getpid` use to
return a second value).  The machine's error convention is applied once, at the
trap boundary, in the one place that already speaks machine.

**Consequence: do not add a carry-return attribute to fcc.**  Nothing is
missing from the compiler -- a C function returning `int` and setting an error
cell is ordinary C.  What is misplaced is FGX's convention, which spreads the
carry contract across every kernel routine instead of confining it to the
dispatcher.  Toolchain-first does not apply to a feature the oracle
deliberately does not have.

**Adopt instead:** `u_error` plus `r_val1`/`r_val2` in the per-task u-area, with
FGX's existing syscall dispatcher performing the single translation it already
performs.  Converted C code then compiles unmodified, and thunks disappear as a
category rather than being written per routine.

Two pseudo-errors come along and are worth having: `ERESTART` re-runs the
syscall after a signal, and `EJUSTRETURN` suppresses the normal return path.
Those are the mechanisms behind BSD's EINTR semantics, which FGX's signal work
has been approximating by hand.

This also folds into seam 3, the process/credential/file-table conversion: the
u-area is where `u_error` and `u_r` live, so the two changes are one change.

### Seam blocker 1 (the DP page): DONE, 2026-08-09.  Do not redo it.

**The section below is kept for its reasoning and is STALE as a work item.**
All five of its ordered steps are implemented and verified:

| step | where |
|---|---|
| generator derives `CFG_DP_KERNELC` | `tools/ninja/genconfig.py` |
| memmap `ERR` retargeted | `include/memmap.s:1205` |
| checker knows the page | `tools/check_bank0_geometry.py:82,151` |
| stage2's mirror updated | `src/boot/stage2.s:123` |
| entry macro written | `KC_ENTER`/`KC_LEAVE`, `include/kernelc.s` |

`check_bank0_geometry.py` reports: arena `$1A00`+153p -> `$B300`, kernel-C DP
`$B300`, DP pids 0..11 `$B400` -> `$C000`.  A session that reads the text below
as a to-do list will redo finished work on the one part of bank 0 whose failure
mode is silent.

### Seam blocker 2 (sleep): the design, measured 2026-08-09

This is what actually gates 1.3, and it is now specified rather than open.

**The register file is 104 bytes, `$98-$FF`** -- not the 68 the seam comment
claimed, and not the 102 a hand re-measurement produced.  Widths are not
recoverable from the EQUs, so `tools/gen_fcc_dp.py` emits `KC_DP_LO` and
`KC_DP_BYTES` into the generated slot map and the switch code must use those
symbols.  A literal in the switch is a second copy of the slot map, and when
the copies disagree the symptom is C state corrupted across a sleep, appearing
in the suspended task rather than the one that overwrote it.

**Where the save area lives: not the TCB and not the sched-entry.**  `TCB_SIZE`
is hard-capped at 64 bytes by an `ERR` and is full; `SE_SIZE` is 32, so the
table needs its own home.

*(Superseded by what was actually built, below.  This paragraph originally
proposed the FAR bank, on the grounds that kernel C's statics live there and
`KC_ENTER` already points DBR at it -- which would have meant an `MVN` from the
bank-0 DP page, and `MVN` **leaves DBR on the destination bank**.  The kernel
bank turned out to be strictly better: `swtch` already runs with DBR there, so
there is no pointer, no `MVN`, and no init.  Kept only so the reasoning is not
re-derived.)*

**THERE IS NO SOFT-STACK PROBLEM.  Kernel C already uses the hardware stack.**
The July audit listed "no kernel soft stack" as blocker 2's second half, and a
first pass at this section designed a kernel-owned bank sliced NPROC+1 ways to
solve it.  Both are wrong, and the generated code says so plainly: `kc_probe.s`
opens `TSC / SEC / SBC #FRAMESIZE / TCS` and closes `TSC / CLC / ADC
#FRAMESIZE / TCS`, with **zero references to `_fcc_sfp` or `_fcc_ssp`.**  Those
are the USERLAND soft-stack pointers; kernel C, compiled with
`-fno-safepoints`, frames on the bank-0 hardware stack.

That stack is the running task's KERNEL stack, which `swtch` already saves and
restores through `SE_KernSP`.  So a C frame suspended by a sleep is preserved
by exactly the mechanism that already preserves a suspended asm routine's
frame, and it is per-task by construction with no new allocation.

The one real cost is the bank-0 lane budget: C frames are wider than the asm
they replace (`kc_probe_FRAMESIZE` is 16 for a four-int function), and the
kernel stack lane is the resource the bank-0 campaign spent itself measuring.
That is a MEASUREMENT to take against the lane budget as VFS code lands, not a
structure to build in advance.

**So blocker 2 is one thing, not two: save and restore the 104-byte DP band.**

**LANDED 2026-08-09 (`2d4f1984d`), with one gap named below.**  `swtch` copies
the band to a per-task slot on the way out and restores it on the way in, gated
on `KCPROBE`; production is byte-identical at 54398 B.  The save area is a
kernel-bank table rather than the far bank -- `swtch` already runs with DBR on
the kernel bank, so that needs no pointer, no `MVN`, and no init, and it costs
nothing in a shipping kernel because the whole thing is inside the gate.  The
copy loops are subroutines so boot can drive them: two slots of offset-derived
patterns, scribble, restore both, check.  Mutation-verified both ways -- a
short restore bound prints `DP SAVE BROKEN`, and a stride under the band fails
the build on an `ERR`.

**BLOCKER 2 IS CLOSED** (`d68b852ee`, `e811f3890`), proven at three levels:

1. *The copy loops* -- boot fills two slots with offset-derived patterns,
   scribbles the band, restores both and checks.  Red on a short bound.
2. *The slot arithmetic* -- the offset was an argument computed identically at
   both call sites, which put it beyond reach of any test.  It is now derived
   from `_curTask` inside the routines, so there is one copy of it and the boot
   check selects slots by setting `_curTask`, driving that code rather than
   stepping around it.  Red on a dropped shift.
3. *The placement in `swtch`* -- the dispatcher stamps the running pid into the
   band on the way in and checks it on the way out.  Red when the restore call
   is removed, after nothing more than booting to a shell and running one
   command.

The end-to-end proof did NOT need a syscall-to-C entry point, which is what
this section previously said was required.  The concurrency the existing tests
already generate is the driver: any two tasks making syscalls across a switch
exercise it.

The dispatcher's marker lives at `KC_DP_MARK` (`$E0`), inside the band so it is
saved and restored, but in the one region of it kernel C cannot reach: the
authoritative DP map assigns `$E0-$E7` to `args.s` and libc scratch, both
userland only, and kernel C links no libc and takes no argv.  `gen_fcc_dp.py`
refuses to emit if fcc ever allocates there.  It previously borrowed word 0 of
the band, which would have started firing against innocent code the day real
kernel C shipped.

What remains before 1.3 can land is not a seam question but a build one: kernel
C is still a debug build (`kernel.kcprobe`, default 0).  Shipping `vfs_bio`
means promoting it, and the flip ON is documented as failing SILENTLY when the
patch tables are not regenerated.

### Seam blocker 1, original investigation (superseded above)

Measured 2026-08-09, so the next session starts from facts rather than a survey:

- **The kernel runs on zero page.**  `FGX_DP_KERNEL EQU $0000`
  (`include/kernel.s:198`), and `include/dpmap.s` fills it edge to edge --
  `_pipeTablePtr` sits at `$FB-FD` with the remainder padded to `$FF`.  fcc
  needs `$BC-$FF` for its register file.  Total collision, confirmed; kernel C
  requires its own page, exactly as the July audit predicted.
- **Bank 0 has no spare page, by construction.**  `CFG_STK_ARENA $1A00` plus
  `CFG_STK_ARENA_PAGES 154` lands exactly on `CFG_DP_KTASKS $B400`, and
  `include/memmap.s` carries an `ERR` making any drift a build error, because
  an overlap corrupts a live task's direct page.
- **There IS room to carve one.**  The stack budget reports 123 of 154 pages
  worst case, so dropping the arena to 153 and placing a kernel-C DP page at
  `$B300` costs nothing real.

**Why this is not a one-line change.**  The geometry is DERIVED from
`kernel.nproc` in `cfg/system.cfg` through the config generator, and it is
mirrored in four places that `tools/check_bank0_geometry.py` polices --
including `src/boot/stage2.s`, which HAND-MIRRORS the values because it
assembles standalone and never sees the shared headers.  So carving the page
touches: the generator, the `ERR` in memmap, the checker's invariants, and
stage2's mirror.  Get one wrong and the failure mode is a silently corrupted
task direct page, not a build error.

**Next step, in order:** teach the generator to derive `CFG_DP_KERNELC`
alongside `CFG_DP_KTASKS`; retarget the memmap `ERR` at the new boundary; add
the page to the checker; update stage2's mirror; rebuild and confirm the boot
smoke test before writing a single line of the entry macro.

### The kernel-C seam is already designed -- do not re-derive it

`docs/history/audits/2026-07-05-fgx-fcc-arch-audit/kernel-c-triage.md` scoped
this in July.  Its findings stand and 0.1 should execute them rather than
rediscover them.  The headline: **fcc has no freestanding mode, but there is no
linker gap** -- it emits Merlin32 `.s` that can be PUT straight into the kernel
link, and single-segment mode addresses globals DBR-relative, which is already
the kernel's convention.  What is missing is a runtime seam, and the blockers
are ranked:

1. **DP collision (the hard one).**  fcc requires a fixed register file at
   `$BC-$FF`; the kernel DP page is full edge to edge.  Needs a dedicated
   kernel-C DP page plus `PHD/TCD ... PLD` at every asm-to-C boundary.
2. **No kernel soft stack.**  `crt0_c.s` seeds `_fcc_ssp` through a syscall and
   the kernel cannot syscall itself.  Needs a boot-time Kmalloc'd stack, and a
   per-task one if C code can cross `_sleep`.
3. **ABI thunks -- RESOLVED, see above.**  Not a thunk per routine and not a
   compiler attribute: adopt BSD's `u_error`/`r_val1` convention so the carry
   translation happens once in the dispatcher, as it does in 2.11BSD.
4. **Reentrancy.**  fcc's DP register file is not reentrant, so an ISR must
   never call C.  Acceptable for the cooperative kernel body; an absolute bar
   for the hardware files.
5. **Size** -- gates in-bank conversion only, and is moot for a module bank,
   which is why the filesystem work goes to a bank rather than into bank $02.

- **0.1 fcc kernel-C spike.**  Teach fcc a freestanding/kernel mode (no libc,
  kernel DP, kernel stack, module calling convention, inline-asm escape) and
  compile into a module bank **two files, not one**:
  - `ufs_bmap.c` (161 lines) -- long arithmetic, the FS side.
  - **`vfs_subr.c` (934 lines) -- the real stress case.**  An earlier draft
    spiked on bmap alone, which would have given false confidence: it exercises
    none of what the Reno half needs, and the Reno half is the one being taken
    verbatim.  Specifically it never touches **function-pointer vectors -- the
    vnodeops table itself, and fcc's weakest documented area** (far-fnptr-in-
    data-initializer and struct-fnptr field drift are both in the project
    record); nor enums (`enum vtype`/`enum vtagtype` are in every VFS
    signature), struct assignment, MALLOC/bzero idioms, varargs (`panic`), or
    sleep across a C call.
  **GATE:** code size and cycles measured against the existing prodos asm path;
  stack high-water against the bank-0 lane budget; and a vnodeops vector that
  actually dispatches.  If fcc kernel C is unaffordable, the language decision
  must be revisited *here*, before anything is built on it.
- **0.2 Struct-layout conformance fixture.**  Lock fcc's PDP-11 layout with a
  regression test that fails loudly if alignment ever changes.
- **0.3 Byte-order ground truth.  DONE 2026-08-09.**  Measured on a live
  2.11BSD PDP-11/70 (kernel #18) reached over telnet, driven by an `expect`
  script -- no local SIMH needed.  `0x01020304` stores as `02 01 04 03`:
  high word first, little-endian within each word, so the 65816 conversion is
  a 16-bit half-swap.  All struct sizes and offsets captured; see the measured
  layout table.  **GATE for goal 2: PASSED.**
- **0.4 Host reader.**  `fgxfs` (Python) reads the image 2.11BSD's own mkfs
  produced -- listing directories and extracting a file byte-exact.  Reading
  somebody else's volume first is the strongest conformance test available,
  and it fails loudly if 0.3 got anything wrong.

### Phase 1 -- VFS lands with UFS as its first client

ProDOS stays root and stays untouched.  The vnode layer arrives alongside it,
serving a **new** filesystem on a second disk.

Attribution comes from **the oracle, not from the disk image being unchanged**.
Every write FGX makes to the UFS volume is checkable by an independent
implementation of the same format -- host `fgxfs fsck` and 2.11BSD's own fsck
under SIMH.  That is a far stronger control than "we did not touch ProDOS", and
unlike the old phase-1 gate it can actually fail.

- **1.0a The root bridge.**  Path resolution starts at a `rootdir` VNODE
  (`vfs_lookup.c:145`), and ProDOS has no vnodeops until phase 4 -- so without
  this, nothing supplies a root.  **The vnode layer gets its OWN root: the UFS
  volume.**  Two namespaces run side by side: the legacy ProDOS path keeps
  serving today's syscalls unchanged, and the new vnode namespace is rooted
  directly at the UFS mount.  Nothing mounts "onto" a ProDOS directory because
  nothing needs to.  Rejected: a read-only ProDOS vnodeops shim (drags phase-4
  work forward and re-imports the key-block identity problem the inversion
  exists to avoid) and a stub root vnode (a synthetic namespace of exactly the
  kind the device-model decision rejected).  Adds no throwaway code -- this
  root is the one the system keeps -- and turns the later root swap from a
  migration into a retirement.
- **1.0b Reentrancy audit.**  BEFORE the buffer cache gains sleeping locks, not
  after: the moment a shared cache can block, a ProDOS operation can sleep
  holding `_fsDirBuf` (`memmap.s:610`) or `_fsPathScratch`, which is #41's
  shape.  Zero `sleep` exists today across `fs.s`, `bitmap.s` and `prodos.s`;
  that is the invariant being broken.
- **1.1 Reno `vnode.h`/`mount.h`**, sized: `VN_MAXPRIVATE` >= 104 (64-byte
  dinode plus ~36 bytes of in-core bookkeeping at fcc widths -- 96 was short
  once `i_diroff`/`i_endoff` are counted, and both are load-bearing in the
  directory slot logic).  Vnode pool >= `FS_MAX_FDS` (30).  First because
  everything below keys on it.
- **1.2 SEAM 3 -- the process/file-table conversion.**  `struct file` with
  DTYPE split, `u.u_ofile[]`, refcounted `ucred`, per-process `nameidata`,
  `u_cmask`, `u_rlimit`.  FGX's FCB becomes (or is replaced by) the BSD file
  table; pipes, sockets and chardevs become `DTYPE_*` entries.  Early, because
  `vfs_vnops.c` is this glue and building over an unconverted FCB converts
  twice.
- **1.3 SEAM 2 -- port `vfs_bio.c`**, vnode-keyed, with sleeping buffer locks:
  `bread/breada/bwrite/bdwrite/bawrite/brelse/getblk/geteblk/getnewbuf/
  biowait/biodone/bgetvp/brelvp/reassignbuf/vflushbuf/vinvalbuf`, the `B_*`
  flags, and `b_vp/b_lblkno/b_blkno/b_resid/b_rcred/b_wcred`.  `blkcache.s`
  becomes the physical layer underneath it and gets its 32-bit block key.
- **1.4 `vfs_subr`** -- getnewvnode/vget/vput/vrele/vgone/vclean/insmntque/
  vflush/**checkalias**/**bdevvp** -- plus `vfs_conf`'s `vfssw[]` and
  `dead_vnops.c` (vgone needs it).
- **1.5 `cdevsw`/`bdevsw`, major/minor (`minor = unit*8 + partition`), and
  `spec_vnops.c`.**  Moved AHEAD of the filesystem: `ufs_vfsops.c`'s `getmdev`
  (`:729`) rejects anything that is not a VBLK vnode, and `mountfs` (`:196`)
  calls `vcount`, `vinvalbuf`, `VOP_OPEN` and `bread` on it.  **A UFS mount is
  impossible without specfs**, so specfs cannot be a late deliverable.
- **1.6 `vfs_lookup`** (namei) **+ `vfs_cache`**.
- **1.7 `vfs_vnops` + `vfs_syscalls`**, on top of the 1.2 file table.
- **1.8 `mount(2)`/`unmount(2)`**, `mount(8)`/`umount(8)`.
- **1.9 Host `fgxfs mkfs` AND host `fsck`, together** -- the oracle ships with
  the tooling, not after the write path it validates.
- **1.10 ufs vfsops**: mount/unmount/root/statfs, superblock, `ialloc`/`ifree`,
  `alloc`/`free` on the 2.11BSD free list, `bmap`.
- **1.11 Read path**: lookup, getattr, read, readdir.
- **1.12 Write path**: write, create, remove, mkdir, rmdir, rename, link,
  truncate **with block reclaim** (#68), unlink-while-open via `VOP_INACTIVE`
  (#66).
- **1.13 `mknod` + on-disk IFCHR/IFBLK inodes + the real `/dev`**, including
  the `ufs_inode.c:185` checkalias-on-iget path.  Closes #76 with `vcount()`;
  gives `/dev/tty` (#60) and one `ttwrite` (#74).
  Known limit to test for deliberately: `vcount` counts vnode REFERENCES, not
  opens, and spec's `VOP_INACTIVE` is `spec_nullop` -- so a transient reference
  held across a sleep at the true last close can suppress `d_close` forever.
- **GATE, five ways:** `mount -t ufs` survives a full read/write exercise; host
  `fgxfs fsck` clean; **2.11BSD's own fsck clean on the same image**; an image
  written by 2.11BSD mounts and reads on FGX; and new tests that go red without
  this phase -- per-component lookup across a mount point, `vcount`-driven
  last-close, `VOP_INACTIVE` reclaim of an unlinked open file.

**This phase is large -- 13 deliverables -- and that is a real risk, not a
presentational one.**  It is the whole kernel plumbing plus the whole
filesystem.  A defensible split is 1.0a-1.8 (seams + VFS core) and 1.9-1.13
(UFS itself), but the first half has nothing to mount and therefore nothing to
test against, so they are kept together until someone identifies a minimal
throwaway vfs type worth building.  (Reno's `mfs` is not it: it is FFS in
malloc'd memory and would drag the whole FFS allocator in.)

### Phase 2 -- on-target fsck, then root swap

- 2.1 **On-target `fsck`** (2.11BSD's, already vendored at
  `vendor/2.11BSD/usr/sbin/fsck`).  Ahead of the swap: FGX writes are
  deferred-sync and not crash-safe, and an unrepairable root is the failure
  mode that ends campaigns.
- 2.2 **stage1 in sector 0 only.**  The disklabel owns sector 1, so stage-1 is
  512 bytes and cannot claim the rest of the boot area.  Stage2 is therefore a
  REAL FILE whose blocks `mkfs` guarantees contiguous, and stage-1 bakes in its
  start block and count and reads them with no name lookup at all.
  **It must be a real file, not a reserved block range**: blocks that are
  neither on the free list nor owned by an inode are exactly what `fsck`
  classifies as missing and salvages back into the free list, so a reserved
  range would be reclaimed and then overwritten -- by our own on-target fsck
  (2.1), or by a real 2.11 system fscking an FGX volume, which is goal 2.  Reading the
  filesystem from the boot block -- superblock, inode 2, scan the root
  directory, follow direct blocks -- does not fit in one sector and is
  dropped.
- 2.3 stage2 reads UFS: kernel plus preload modules by path.
- 2.4 Build system: `disk_src` staging moves to `fgxfs`; `make_disk.sh`, the
  ninja image rules, `tools/make_floppy.sh` and ~90 test manifests.
- 2.5 **`/dev` becomes part of root.**  The real `/dev` and specfs already
  exist by this point (delivered in the UFS phase, mounted at `/dev` while root
  was still ProDOS -- see the device model section).  What happens here is that
  it stops being a separate mount and becomes a directory of the UFS root, and
  `mknod` runs at image-build time via `fgxfs`.  `/dev/tty` (#60) and the
  single `ttwrite` (#74) land with specfs, not here.
- 2.6 **Permissions.**  mode/uid/gid on disk, `VOP_ACCESS` in namei, `chmod`/
  `chown`/`umask` syscalls and tools, setuid bit.  The kernel's existing
  credential model (`U_Ruid`/`U_Uid`/`U_Svuid`, #73's setpgid check) finally
  has a filesystem that can express ownership.
- **GATE:** boots from UFS with no ProDOS module loaded at all; suite green.

### Phase 3 -- ProDOS as a type

- 3.1 `mount -t prodos`, read/write, mountable anywhere in the tree (goal 4).
- 3.2 Retire the last ProDOS assumptions from the build and the docs (goal 1).

## Risks

| Risk | Gate |
|---|---|
| fcc kernel-C unaffordable in size or speed | 0.1 -- and the spike must include `vfs_subr.c`, not just `ufs_bmap.c`, or the function-pointer-vector risk goes untested |
| Byte order wrong -> goal 2 silently fails | 0.3 observed bytes; 0.4 reads a foreign volume |
| The Reno/2.11 seam | convert function by function with both sources open; 2.11's ufs is Reno's ancestor, so the mapping is close to 1:1 |
| **Reentrancy.  The current FS layer NEVER SLEEPS** -- zero `sleep` in both `fs.s` and `prodos.s` -- which is why its shared state (`_fsDirBuf`, and above all the `_fsPathScratch` resolver work area) is safe.  Reno's VFS sleeps by design: vnode locks, VXLOCK waits in vget/vgone, buffer waits.  FGX has preemption.  Every one of those singletons becomes a cross-process corruption the moment namei can block -- the exact shape of #41 (shared `_kTtyRdPtr` DP cell across a sleep) | a named phase-1 deliverable carrying the same weight as stack depth: audit every FS singleton, and either make it per-process or hold a lock across the sleep |
| Stack depth -- VFS chains are deeper than FGX's current path, against 154-page bank-0 arena and NPROC 12 | measure HWM at every phase gate using the B3 campaign's existing tooling |
| Crash safety: UFS is far less forgiving than ProDOS | host fsck at 1.5 as the oracle, on-target fsck at 2.1 ahead of the swap; consider synchronous metadata writes initially and optimise later |
| Data-structure memory: vnodes, buffer headers, mount table | budget item at 1.1; VFS lives in a module bank, but its data has to be placed deliberately |
| The bio seam: Reno's buffer cache is VNODE-keyed (`bread(vp,...)`), FGX's is dev-keyed | decided in 1.0, in writing, before any kern file is ported |

## Open structural decisions from the adversarial review

Factual errors found by the review are corrected inline above.  These three are
structural and are the maintainer's call, not mine.

**O1. RESOLVED (the maintainer, 2026-08-09): inverted.**  The VFS lands with UFS as its
first client; ProDOS is retargeted onto vnodeops once, in phase 3, read-only
first.  The phases above reflect this.  The argument, kept because it is the
reason:  Phase 1.4
is not the "retarget" the plan calls it: the 22 FOPs take a whole relative path
(`include/fst.s`) and `FOP_Lookup` is `_fop_enosys` (`prodos.s:190`), so
per-component lookup against a parent vnode **must be written new** into 5,378
lines of asm.  Then it hits a wall the codebase already documents: in-core
inode identity is `(device, key block)` (`inode.s:32`) and the key block
CHANGES when a write promotes seedling to sapling to tree
(`write.s:153,469`) -- while Reno's vget hash and the namei cache both assume
vnode identity is immortal until reclaim.  So the plan's keystone phase is
larger than writing UFS itself, and every hour of it is spent adapting the
filesystem the campaign exists to demote.  Retarget ProDOS **once, in phase 3,
read-only first.**  Cost of inverting: the "byte-identical image" attribution
argument is lost, and is replaced by host-fsck-as-oracle, which the review
argues is stronger anyway (see O3).

**O2. RESOLVED (the maintainer, 2026-08-09).**  The review was right that
`cdevsw`/major-minor was scheduled two phases after `spec_vnops` consumed it;
it moves to phase 1.6.  The review's other half -- that synthesized `/dev` is
architecturally fine because Reno's `bdevvp()` builds device vnodes with no
filesystem behind them -- is **overruled by decision**: `/dev` is real, on
disk, from the start.  See the device model section for the consequences,
including that specfs and therefore #76 now wait for UFS.

**O4. RESOLVED (2026-08-09): the root bridge.**  The second review found that
phase 1 had no root vnode for namei.  Resolved by giving the vnode layer its
own root at the UFS volume and running the legacy ProDOS path beside it -- see
deliverable 1.0a.

**O3. RESOLVED (the maintainer, 2026-08-09): adopted in full.**  Folded into the phases
above -- host `fsck` ships with the host tooling at 1.5, `mount(2)` moved to
1.4, the 0.1 spike widened to `vfs_subr.c`, and every phase now owes a test
that goes red without its own machinery.  The argument, kept because it is the
reason:
  - The phase-1 gate is vacuous on both clauses.  The image is byte-identical
    *by construction* since phase 1 changes no disk-build inputs, and the
    manifests test only behavior reachable today -- none exercises
    per-component lookup, a mount inside another FS, alias accounting, or
    inactive-time reclaim.  It would pass with a dead namei cache, a `vcount`
    that never decrements, and a `VOP_INACTIVE` that never fires.  Per this
    project's own recorded discipline: a test that does not go red without the
    change is not coverage.  **Every phase must ship at least one test that
    goes red without that phase's machinery.**
  - Host `fsck` moves from 2.6 to 2.1.  An oracle scheduled after the write
    path it validates has already lost most of its value.  `mount(2)` moves to
    the front of phase 2 for the same reason -- the phase gate's own command
    needs it.
  - The 0.1 spike must include a Reno VFS file, not just `ufs_bmap.c`.  That
    file is 161 lines of long arithmetic and exercises none of what the Reno
    half needs: **function-pointer vectors (the vnodeops table itself, and
    fcc's weakest documented area)**, enums (`enum vtagtype`/`enum vtype` are
    in every VFS signature), struct assignment, MALLOC/bzero idioms, varargs
    (`panic`), sleep across a C call.  A green bmap proves fcc can do 32-bit
    arithmetic in a module bank, which was already known.  `vfs_subr.c` is the
    honest stress case.

Also flagged and unpriced, lower confidence but worth resolving before phase 1:
what happens to pipes and sockets, which occupy FCB slots today but in
Reno are a DTYPE split of the file table; whether exec holds a vnode; cwd as a
held vnode; root-mount bootstrap ordering; and namespace migration -- ProDOS
forbade underscores and was case-insensitive with 15-char names, so some
manifests will fail for naming reasons that will look like VFS bugs.

### RESOLVED, 2026-08-09

Standing rule for this campaign (the maintainer): **let 2.11BSD be the guide on
architecture; where it gives no clear answer, take the advisory review's
recommendation.  Size things by educated guess relative to BSD, and make
every size a compile-time knob so it can be turned once measured in use.**

- **Pipes and sockets: full DTYPE split, no shim.**  `struct file` gains an
  `f_ops` vector (`fo_read`/`fo_write`/`fo_ioctl`/`fo_select`/`fo_close`) with
  `DTYPE_VNODE`, `DTYPE_SOCKET`, `DTYPE_PIPE`.  Take NEITHER ancestor's pipe
  implementation: 2.11BSD backs pipes with inodes on the root device, which
  couples pipes to UFS and puts disk traffic behind every pipe, and Reno makes
  pipe() a socketpair, which is heavier than FGX's working pipe machinery for
  no gain.  FGX's existing pipe table behind an ops vector is where 4.4BSD
  itself ended up.  A shim is specifically excluded: it produces the
  half-converted state this plan already identifies as the worst outcome.
- **exec does NOT hold a vnode.**  BSD holds the text vnode for demand paging
  and shared/swappable text, neither of which exists here -- FGX loads the
  whole image at exec and closes the file, so nothing can fault against it
  later.  The only casualty is ETXTBSY, which without paging protects nothing.
  The gain is NPROC vnodes not held out of the pool, and unlink-of-a-running-
  binary working through ordinary reclaim.  Revisit only if shared text or
  swap ever exists.
- **cwd IS a held vnode.**  `u_cdir` as a `v_usecount` reference: chdir
  resolves, vrefs, vreles the old; fork vrefs; exit vreles.  A string cwd has
  the wrong semantics (renaming an ancestor silently moves you; a removed cwd
  resurrects), costs a resolution per syscall, and would mean rewriting
  namei's entry, since Reno's relative lookup starts from a vnode.  Every BSD
  since v7 holds the reference.
- **Root-mount bootstrap: Reno's sequence, with `bdevvp()`.**  `cdevsw`/
  `bdevsw` are compiled in and live from boot (1.5); `bdevvp(rootdev)`
  manufactures the root device vnode with no filesystem behind it; `ufs_mountfs`
  runs on that vnode; `rootdir = VFS_ROOT(mp)`.  This does not conflict with
  the no-synthesized-`/dev` decision above: `bdevvp` makes one anonymous
  vnode, not a namespace, and mounting root needs no `/dev` at all -- device
  NODES come later, off the mounted filesystem, exactly as that section says.
  Phase 1's side-by-side UFS mount uses the same path with
  minor = unit*8 + partition.
- **Namespace migration is much smaller than feared.**  Measured: ZERO test
  manifests reference uppercase paths, so case-sensitivity breaks nothing.
  The real item is dotfile un-mangling (`.profile`/`.cshrc`/`.login` ship as
  `DOT.*`): three staged files, two sites in `prodos.s`, one line of
  `docs/filesystem.md`.

### Two deliverables the phase list was missing

Both surfaced by the advisory review; neither had a number, and the first is
on the critical path that 1.2 was wrongly believed to hold.

- **Kernel C surviving `_sleep`.**  The whole Reno VFS sleeps by design, fcc's
  DP register file is a single shared page, the kernel-C DP page is one page
  rather than per-task, and kernel C is still a debug build
  (`kernel.kcprobe`, default 0).  The 0.1 spike proved compile and dispatch,
  not sleep-crossing.  **This, not 1.2, is what gates 1.3.**
- **The buffer pool budget.**  1.1 sized vnodes and mounts and skipped
  `struct buf` and its arena, the largest RAM item in the campaign.  Closed by
  the 1.1 revision: the 2.11BSD header does not embed its data, so headers and
  arena place independently.

### Ordering corrections

- **1.2-before-1.3 is SOFT.**  `vfs_bio.c`, `vfs_subr.c` and `spec_vnops.c`
  take vnode and cred arguments and never touch `struct file`.  The hard
  constraint is 1.2-before-**1.7** (`vfs_vnops.c` is the file-table glue).
- **The singleton conversion campaign is very likely unnecessary**, and is
  mis-ordered as scheduled.  See the reentrancy audit: disk I/O here is
  synchronous SmartPort PIO, so `biowait` has nothing to wait for and the
  buffer LOCK waits `vfs_bio` needs sit above the block driver.  Confining
  sleeps there keeps the no-sleep invariant permanently true and trades sixty
  conversions for one rule -- a device is cached by exactly one stack, never
  both.  It is also mis-ordered against 1.2, whose deletion of the FCB would
  undo the prescribed per-FCB conversion targets.
- **The `u_error`/`r_val1` dispatcher conversion is decision-free** and was
  available all along: the convention is already settled above, and none of
  the four questions touch it.

## Non-goals

FFS (cylinder groups, fragments), LFS, MFS, NFS, quotas, 4.4BSD's
`vnode_if.c` descriptor-generation machinery, and layered filesystems beyond
what specfs itself requires.  Symlinks are in scope -- `IFLNK` exists in
2.11BSD and costs little once inodes are real.

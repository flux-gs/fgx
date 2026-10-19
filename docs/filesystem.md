# FGX Filesystem

> **Describes the shipped system.** The filesystem is 2.11BSD's UFS, reached
> through a vnode layer ported from 4.3BSD-Reno (2.11BSD has no vnodes to
> port). ProDOS is a loadable filesystem type for mounting ProDOS volumes; it
> is not the root and the machine does not boot from it. Every ported file is
> registered with its upstream in [PROVENANCE.md](PROVENANCE.md). Where this
> doc and the code disagree, the code wins.

## Layering

A file operation crosses four banks on its way to the disk:

```
user process            COP syscall
  |
core bank               src/kernel/syscall.s       _Sys_* handlers, path copy-in
  |                     src/drivers/fs/fcb.s       per-task fd table (FCBs)
  |                     src/drivers/fs/fs.s        thin _Fs_Root* thunks
  v
far bank                src/kernel/far/root_mount.c   root mount; root_* routing
  |                     src/kernel/vfs/vfs_syscalls.c syscall bodies, mount(2)
  |                     src/kernel/vfs/vfs_file.c     the open-file table
  v   (vfs_import.s: VT_VFSCORE)
vfs.mod                 namei, vnodes, vn_*, buffer cache, specfs, deadfs
  |   (VFS_* / VOP_* vectors)
  v
ufs.mod + ufsdir.mod    2.11BSD UFS              (the root, and any UFS mount)
prodos.mod + prodosw.mod   ProDOS type           (loaded on demand)
  |   bread / bwrite / bdwrite
  v
vfs.mod                 vfs_bio.c -> bio_strategy.c -> kc_blkio (KSVC_BLKIO)
  |
core bank               src/kernel/jumptable.s @kc_blkio -> Blk_Read / Blk_Write
                        src/drivers/block/block.s     SmartPort, via a bank-0
                                                      trampoline
```

| Layer | Files | Upstream |
|-------|-------|----------|
| Syscall entry, fd table | `src/kernel/syscall.s`, `src/drivers/fs/{fcb,fs}.s` | FGX (assembly) |
| Root mount, path routing | `src/kernel/far/root_mount.c` | FGX-Origin; the sequence is Reno's `ufs_mountroot` |
| Syscall bodies, mount list | `src/kernel/vfs/vfs_syscalls.c` | Reno `kern/vfs_syscalls.c`, `kern/sys_generic.c` |
| Open-file table | `src/kernel/vfs/vfs_file.c`, `file.h` | Reno `kern/kern_descrip.c`; `getf` and `DTYPE_PIPE` from 2.11BSD |
| Path walk | `src/kernel/vfs/vfs_lookup.c` | Reno `kern/vfs_lookup.c` |
| Vnode pool | `src/kernel/vfs/vfs_subr.c`, `vnode.h` | Reno `kern/vfs_subr.c` |
| File/vnode glue | `src/kernel/vfs/vfs_vnops.c` | Reno `kern/vfs_vnops.c` |
| Type switch | `vfssw` in `vfs_vnops.c`, `vfsops.h` | Reno `kern/vfs_conf.c`, `sys/mount.h` |
| Name cache | `src/kernel/vfs/vfs_cache.c` | Reno `kern/vfs_cache.c` |
| Buffer cache | `src/kernel/vfs/vfs_bio.c`, `buf.h` | Reno `kern/vfs_bio.c` |
| Device vnodes | `src/kernel/vfs/spec_vnops.c`, `dead_vnops.c` | Reno `kern/spec_vnops.c`, `kern/dead_vnops.c` |
| flock(2) | `src/kernel/vfs/kern_flock.c` | Reno `vn_lock`/`flock`, two lines from 2.11BSD `sys_inode.c` |
| UFS mount, superblock | `ufs_vfsops.c`, `ufs_sb.c` | 2.11BSD `sys/ufs_mount.c`, Reno `ufs/ufs_vfsops.c` |
| UFS allocators | `ufs_alloc.c` | 2.11BSD `sys/ufs_alloc.c` |
| UFS block map | `ufs_bmap.c` | Reno `ufs/ufs_bmap.c` structure, 2.11BSD arithmetic |
| UFS in-core inode | `ufs_inode.c`, `ufs_dinode.c` | Reno `ufs/ufs_inode.c` |
| UFS vnode ops, lookup | `ufs_vnops.c`, `ufs_lookup.c` | Reno `ufs/ufs_vnops.c`, `ufs/ufs_lookup.c` |
| ProDOS type | `prodos_{node,vfsops,vnops,write}.c`, `prodos.h` | FGX-Origin (no BSD carried ProDOS) |

The VFS, UFS and ProDOS C lives in `src/kernel/vfs/`, and the far bank's own
C (`root_mount.c`, `dev_mount.c`, `root_sysctl.c`, `vfs_seam.c`) in
`src/kernel/far/`. Which bank each file is assembled into is the PUT list of
its container:

| Container | C it carries | Loaded |
|-----------|--------------|--------|
| far bank (`src/kernel/far/far.s`) | `vfs_file.c`, `vfs_syscalls.c`, `root_mount.c`, `dev_mount.c`, `root_sysctl.c`, `vfs_seam.c` | segment of `/fgxunix` |
| `vfs.mod` (`src/modules/vfs/vfs.s`) | `vfs_bio.c`, `bio_strategy.c`, `dead_vnops.c`, `vfs_subr.c`, `dev_chrtoblk.c`, `kern_subr.c`, `vfs_init.c`, `vfs_lookup.c`, `vfs_vnops.c` | segment of `/fgxunix` |
| `ufs.mod` (`src/modules/ufs/ufs.s`) | `kern_time.c`, `kern_flock.c`, `kern_fsetattr.c`, `ufs_sb.c`, `ufs_dinode.c`, `ufs_vfsops.c`, `ufs_alloc.c`, `ufs_bmap.c`, `ufs_inode.c` | segment of `/fgxunix` |
| `ufsdir.mod` (`src/modules/ufsdir/ufsdir.s`) | `spec_vnops.c`, `ufs_vnops.c`, `ufs_lookup.c`, `vfs_cache.c` | segment of `/fgxunix` |
| `prodos.mod` (`src/modules/prodos/prodos.s`) | `kern_epoch.c`, `prodos_node.c`, `prodos_vfsops.c`, `prodos_vnops.c` | by `mount_prodos(8)` |
| `prodosw.mod` (`src/modules/prodosw/prodosw.s`) | `kern_time.c`, `prodos_write.c` | by `mount_prodos -o write` |

The split into several 64 KB module banks is a size decision, not a design
one: each module's header gives the byte budget that forced it. Cross-module
calls go through generated import shims (`vfs_import.s`, `ufs_import.s`,
`prodos_import.s`, from `tools/gen_mod_imports.py`). `vfs`, `ufs` and
`ufsdir` cannot come from `/etc/modload.conf` because that file is read through
the filesystem; `tools/mkfgxunix.py` puts them in the kernel image and stage 2
places them at boot (see `fgxunix(5)` and [modules.md](modules.md)).

## On-disk format

The root volume is a 2.11BSD filesystem, byte-compatible with a PDP-11
2.11BSD system. The format comes from `vendor/2.11BSD/usr/sys/h/`:

| Item | Value | Source |
|------|-------|--------|
| Filesystem block | 1024 bytes (`FS_BLKSIZE`); two 512-byte device blocks | `h/param.h` `MAXBSIZE`; `src/kernel/vfs/fsparam.h` |
| Superblock | block 1; free list of `NICFREE` 50 blocks, inode cache of `NICINOD` 100 | `h/fs.h`; `src/kernel/vfs/ufs_fs.h` |
| Inode | `NADDR` 7 block addresses: 4 direct, then single, double, triple indirect; `INOPB` 16 per block; root inode 2 | `h/inode.h`; `ufs_fs.h`, `ufs_dinode.c` |
| Directory | `struct direct` with a 16-bit `d_ino`; `DIRBLKSIZ` 512; `MAXNAMLEN` 63 | `h/dir.h`; `src/kernel/vfs/dir.h` |
| Clean flag | `MNT_CLEAN` in `fs_flags` (2.11BSD update #456, later than the vendored tree, whose `h/fs.h` has `fs_flags` but not the bit) | `src/kernel/vfs/mount.h` |

Byte order is the PDP-11's: 16-bit fields are little-endian and overlay the
65816 directly; 32-bit fields are stored high word first. The kernel decodes
the superblock and inodes into in-core structures (`ufs_sb.c`, `ufs_dinode.c`)
instead of overlaying the disk bytes, which is why `struct ufsmount` embeds its
superblock (`ufsmount.h`). The `tools/fgxfs.py` docstring lists every field by
width.

Names are bytes: case-sensitive, any character but `/` and NUL, up to
`MAXNAMLEN` 63. Paths are limited to `MAXPATHLEN` 128 (`fsparam.h`), half of
2.11BSD's 256 (`vendor/2.11BSD/usr/sys/h/param.h`).

## Boot and the root mount

1. Stage 1 (`src/boot/loader.s`, sector 0) reads stage 2 from a block list
   baked in by `tools/bake_stage2.py`; `/boot` is an ordinary file on the
   volume.
2. Stage 2 (`src/boot/stage2.s`) has its own UFS reader. It finds `/fgxunix`
   (named by `/etc/boot.conf`) and places each segment.
3. `root_mount()` (`src/kernel/far/root_mount.c`) does Reno's `ufs_mountroot`
   sequence: `bdevvp(ROOT_UNIT 0)`, `ufs_mountfs`, `vfs_setroot`, then makes the
   root the head of the mount list. The boot device is always unit 0. The root
   is mounted **read-only**, as Reno does, so fsck can check it.
4. `/etc/rc` (`disk_src/etc/rc.in`) runs `/sbin/fsck -p` on an autoboot, then
   `/sbin/mount -u -w /` to make the root writable, then starts `update(8)`.
5. `vfs_syncclean()` (`vfs_syscalls.c`) is the shutdown sync: it sets
   `MNT_CLEAN` on every volume that was clean at mount, so the next boot's
   `fsck -p` can skip it.

`/etc/fstab` lists the root as `/dev/sd0 / ufs rw 1 1`.

## Mounting and the namespace

There is one namespace rooted at the UFS root. Other volumes are attached to
directories with mount(2).

| Piece | Where |
|-------|-------|
| Type switch `vfssw[]`, indexed by `MOUNT_*` | `vfs_vnops.c`; each filesystem module fills its row with `vfs_setvfsops` in `mod_init` |
| Types | `MOUNT_UFS` 1, `MOUNT_PRODOS` 10 (FGX-local) (`src/kernel/vfs/vfsops.h`, `toolchain/include/sys/mount.h`) |
| `struct vfsops` | `vfsops.h`: mount, unmount, root, statfs, sync, init. Reno's `vfs_start`, `vfs_quotactl`, `vfs_fhtovp` and `vfs_vptofh` are not carried (no async mounts, no quotas, no NFS) |
| mount(2) | `SYS_MOUNT` 21: 2.11BSD's number, Reno's `(type, dir, flags, data)` arguments; body `vfs_mountat` |
| umount(2) | `SYS_UMOUNT` 22: takes the **device**, as 2.11BSD does; body `vfs_unmountdev` |
| Mount table | `VFS_NMOUNT` 14 slots (`fsparam.h`) plus the root's static mount |
| Flags | `MNT_RDONLY`, `MNT_NOEXEC`, `MNT_NOSUID`, `MNT_NODEV`, `MNT_UPDATE` (`mount.h`) |
| getfsstat(2) / statfs(2) | `SYS_GETFSSTAT` 67, `SYS_STATFS` 114; `vfs_getfsstat` walks the mount list |

namei follows mount points both ways (`v_mountedhere` down,
`mnt_vnodecovered` up) and follows symbolic links up to `MAXSYMLINKS` 8 before
answering `ELOOP` (`vfs_lookup.c`). Names up to `NCHNAMLEN` 31 bytes go in the
name cache (`namei.h`); longer names are looked up every time.

### The ProDOS type

`prodos.mod` mounts and reads ProDOS volumes (lookup, read, readdir) and owns
the vnode vector; `prodosw.mod` adds the write half (the volume bitmap,
write, create, remove, rename, truncate). Neither loads at boot.
`mount_prodos(8)` loads `prodos` with modload when mount(2) answers `ENODEV`,
and `prodosw` too when `-o write` is given. Without `-o write`, or without
`prodosw`, the volume is mounted read-only and mount_prodos says so.

ProDOS names are folded to upper case on lookup and must be `[A-Z0-9.]`,
starting with a letter, at most 15 bytes; readdir returns the GS/OS display
case or lower case. A GS/OS extended file appears as two names: `NAME` (data
fork) and `._NAME` (AppleDouble resource fork and Finder info). See
`src/kernel/vfs/prodos_vnops.c` and
[history/plans/2026-09-13-prodos-fst-design.md](history/plans/2026-09-13-prodos-fst-design.md).

## Buffer cache and the block driver

| Layer | Detail | Where |
|-------|--------|-------|
| Buffer cache | `NBUF` 16 buffers of `FS_BLKSIZE` 1024 bytes, vnode-keyed hash chains, LRU free list; `bread`, `bwrite`, `bdwrite` (delayed write), `bawrite`, `bflush` | `vfs_bio.c`, `fsparam.h` |
| Strategy | **Synchronous**: one 1024-byte buffer is two 512-byte device transfers, and `biodone` runs before return, so no filesystem sleep is a disk wait | `bio_strategy.c` |
| Kernel-C to driver | `kc_blkio(dev, blkhi, blklo, addr, isread)`, `KSVC_BLKIO` through `SYS_KCALL`; sleep-free (checked by `tools/check_fs_sleep_invariant.py`) | `src/modules/common/kc_sys.s`, `src/kernel/jumptable.s` |
| Block driver | `Blk_Read` / `Blk_Write` / `Blk_Status`; 32-bit block numbers (`_blkNum` + `_blkNumHi`) | `src/drivers/block/block.s` |
| Device table | `Dev_Init` scans slots 1..7 for SmartPort controllers and enumerates their units; the boot device is entry 0 | `src/drivers/dev/dev.s` |
| Legacy block cache | a 512-byte copy cache inside `Blk_Read`/`Blk_Write` (`BLKCACHE_NBUF` in `include/fs.s`), skipped for a device marked `DEV_FLAG_VFSOWNED` | `src/drivers/block/blkcache.s` |

The superblock is written back when its free-list batch empties (upstream's
policy) and on sync. `update(8)` calls sync(2) every 30 seconds;
`vfs_sync` flushes delayed buffers and calls each mount's `VFS_SYNC`.

## Device files

Device nodes are ordinary inodes on the root (`IFCHR`/`IFBLK`), made at image
build time. A device vnode wears specfs's vector (`spec_vnops.c`), so its
operations reach a driver instead of the filesystem's data blocks.

FGX has no `cdevsw`/`bdevsw`. `dev_t` is a single-major index:

| Kind | `rdev` means | Nodes |
|------|--------------|-------|
| Block | SmartPort unit number | `/dev/sd0`..`/dev/sd7` (one per unit the slot-7 card can carry, attached or not, as 2.11BSD's MAKEDEV does) |
| Character | chardev registry index (`src/kernel/chardev.s`, `CHARDEV_MAX` in `include/chardev.s`) | `null`, `console`, `tty`, `ttyv1`..`ttyv3`, `ptyp0`/`ttyp0`, `ptyp1`/`ttyp1`, `tty00`, `tty01`, `bpf0`, `cda`, `klog`, and the raw disks `rsd0`..`rsd7` |

The node lists are in `tools/ninja/gen.py` (`DEV_NODES`, `VC_DEV_NODES`,
`RAW_DISK_NODES`, `MODULE_DEV_NODES`, `ROOT_BLKUNITS`). The same lists
generate the mknod table the image build uses, `src/kernel/far/dev_nodes.c`
(which the kernel checks against the live registry at boot), and
`include/devnodes.s` (the fixed index each module registers at,
`CDF_FIXED`). So a node's number and its driver cannot disagree.

`/dev/rsd<n>` is the block driver's character face (`src/drivers/block/rawdisk.s`,
Reno's `physio` without the sleep): it bypasses the buffer cache. fsck reads
non-root filesystems through it and the root through the block device, so its
transfers share the cache the kernel writes through. `dev_chrtoblk.c`
(generated) maps a raw node back to its block node.

## Descriptors and the file table

BSD's three tables, as `file.h` describes them:

| Table | FGX | Size |
|-------|-----|------|
| Descriptor | Two arrays kept in step: the core bank's per-task fd table of FCB pointers (`Task_AllocFdTable`, `src/drivers/fs/fcb.s`) and Reno's per-process `ofile_pool` of `struct file *`, indexed by pid because kernel C has no u-area (`vfs_file.c`) | `FS_MAX_FDS` 30 per process (= 2.11BSD `NOFILE`) |
| File | `struct file`, shared by every descriptor from one open(2), with Reno's `f_count`, `f_offset`, `f_flag` and `f_ops` | `NFILE` 64 system-wide (`fsparam.h`); exhaustion answers `ENFILE` |
| Vnode | the file itself | `VNODE_POOL` 64 (`fsparam.h`) |

`_Fcb_Alloc` takes the lowest free fd (0, 1 and 2 included, once closed) and
mirrors it into the file table (`kdesc_alloc`); `_Fcb_FileOf` reads the
`struct file *` back for read and write. A descriptor's type is BSD's
`f_type`: `DTYPE_VNODE` 1 and `DTYPE_SOCKET` 2 from Reno, `DTYPE_PIPE` 3 from
2.11BSD (Reno has no pipe type). A vnode descriptor dispatches through
`f_ops` (`vnops`, `vfs_vnops.c`) in the far bank; sockets and pipes run their
own arms in the core bank. A device is a vnode, with no descriptor type of its
own. `FCB_RefCount` and `f_count` count descriptors across fork.

Init starts with an empty table, as 2.11BSD's does; a console user opens
`/dev/console`.

## Current directory

The cwd is a vnode, Reno's `u_cdir`, kept per process in `vfs.mod`
(`vfs_cdir`, `vfs_chdir`, `vfs_fchdir`; fork and exit through
`root_cdirfork`/`root_cdirexit`). Relative paths start there. There is no
getcwd syscall: `getwd(3)` (`toolchain/lib/libc_c/getwd.c`, from 2.11BSD)
walks `..` and matches each level by inode.

## Credentials and permissions

FGX follows 2.11BSD: there is no `struct ucred`. The effective and real ids
live in the u-area (`include/kernel.s`) and the filesystem reads them with
`kc_curuid`/`kc_curgid`; `f_cred` is carried at Reno's offset and always 0
(`file.h`). `ufs_access` checks the mode bits; exec honours set-id bits and
`MNT_NOSUID`/`MNT_NOEXEC` (`vn_execchk`, `vn_execsugid`, `ld_exec_check`). open(2) masks the
create mode with the umask and `07777 &~ S_ISVTX`, as Reno does
(`_Sys_Open`, `_Sys_ApplyCmask`).

## Filesystem syscalls

Numbers are in `include/loader.s`; the dispatch table is `_Syscall_Table` in
`src/kernel/syscall.s`.

| # | Call | # | Call |
|---|------|---|------|
| 3 / 4 | read / write | 41 / 89 | dup / dup2 |
| 5 / 6 | open / close | 49 | listdir (FGX, see below) |
| 9 | link | 65 | ioctl |
| 10 | unlink | 67 | getfsstat |
| 12 | chdir | 88 | pipe |
| 15 / 16 | chmod / chown | 92 / 94 | mkdir / rmdir |
| 18 | stat | 93 | utime (epoch atime/mtime; `root_utimes`) |
| 19 | lseek | 95 | rename |
| 21 / 22 | mount / umount | 97 / 98 | fsync / sync |
| 28 | fstat | 103 | ftruncate |
| 33 | access | 104 | umask |
| 111 | lstat | 112 / 113 | readlink / symlink |
| 114 | statfs | 115 | fchdir |
| 122 / 123 | readv / writev | 127 / 128 | fcntl / flock |
| 129 / 130 | fchown / fchmod | | |

`struct stat` is 2.11BSD's exact 52-byte layout, spares included
(`vendor/2.11BSD/usr/sys/h/stat.h`). It lives in three places, held together
by `tools/check_stat_layout.py`: `include/fs.s` (`STX_*`),
`toolchain/include/sys/stat.h`, and `src/kernel/vfs/statlayout.h`.

## What differs from 2.11BSD and Reno

| Difference | Why |
|------------|-----|
| Vnode layer from Reno, UFS from 2.11BSD | 2.11BSD has no vnodes; the on-disk format stays 2.11BSD's so volumes interchange with a PDP-11 |
| Superblock and inodes decoded, not overlaid | PDP-11 32-bit word order differs from the 65816's |
| No u-area for kernel C: descriptor arrays and nameidata slots indexed by pid | kernel C runs on its own direct page with fcc's register file |
| No `struct ucred` | 2.11BSD has none; a refcounted credential would be a pointer into module banks |
| Directories are read with `SYS_LISTDIR`, not read(2) or getdirentries | libc's `opendir` takes one snapshot of `ino:2 name\0` records into a 2048-byte buffer (`toolchain/lib/libc_c/dir.c`); a larger directory is truncated |
| `MAXPATHLEN` 128, not 256 | namei's path buffers are per-process storage rather than Reno's per-call malloc (`fsparam.h`) |
| Strategy is synchronous | SmartPort PIO is synchronous; it keeps every filesystem sleep above the driver |
| `dev_t` is a flat index; no `cdevsw`/`bdevsw` | one block driver and one chardev registry |
| The filesystem is in loadable-format modules, pre-staged in `/fgxunix` | a 64 KB bank cannot hold it; a module read through the filesystem cannot be the filesystem |
| ProDOS is a mountable type loaded at mount time | no BSD carried ProDOS; mount_prodos(8) loading it on `ENODEV` has no BSD counterpart |

## Tools

On the target (staged by `tools/ninja/manifest.json`):

| Tool | Path | Upstream |
|------|------|----------|
| fsck | `/sbin/fsck` (static) | 2.11BSD `usr/sbin/fsck` |
| mount, umount | `/sbin/mount` (static), `/sbin/umount` | 2.11BSD mount(8), umount(8) |
| mount_prodos | `/sbin/mount_prodos` | 2.11BSD `mount_ufs.c` as a standalone `mount_<type>` |
| df | `/bin/df` | 2.11BSD df(1) |
| update | `/sbin/update` | 2.11BSD update(8) |
| sync, stat, ln, chmod, chown (`/sbin`), mkdir, rmdir, mv, rm, touch, tar | `/bin` | see [PROVENANCE.md](PROVENANCE.md) |

There is no mkfs, newfs or mknod on the target; volumes and device nodes are
made on the host.

On the host:

| Tool | Does |
|------|------|
| `tools/fgxfs.py` | Independent reader, writer and fsck for the 2.11BSD format (`mkfs`, `ls`, `cat`, `put`, `mkfile`, `mkdir`, `symlink`, `link`, `mknod`, `chown`, `fsck`, `dump`, `--self-test`); shares no code with the kernel |
| `tools/make_ufsboot.sh` | Builds the root image `disk/fgxufs.po` with fgxfs: `/boot`, `/fgxunix`, the `disk_src/` tree, device nodes, symlinks and hard links from `build/dev_nodes.list`; then bakes stage 2 |
| `tools/bake_stage2.py` | Writes stage 2's block list into stage 1's sector |
| `tools/mkfgxunix.py` | Builds `/fgxunix`: core, far and tty banks plus `vfs`, `ufs`, `ufsdir` |
| `tools/ufscorrupt.py` | Builds deliberately broken UFS volumes for the fsck tests |

## See also

- [modules.md](modules.md) -- the FGXM container the filesystem modules use
- [networking.md](networking.md) -- sockets, the other descriptor type
- [PROVENANCE.md](PROVENANCE.md) -- every ported file and its deltas
- [history/plans/2026-08-09-ufs-migration-campaign.md](history/plans/2026-08-09-ufs-migration-campaign.md) -- why the root moved from ProDOS to UFS
- man pages: `fsck(8)`, `mount_prodos(8)`, `df(1)`, `sync(2)`, `fgxunix(5)`

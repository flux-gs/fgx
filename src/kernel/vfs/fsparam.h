/* fsparam.h -- scalar types and pool sizes for the FGX VFS.
 *
 * 2.11BSD's sys/types.h and sys/param.h, reduced to what the VFS needs.  The
 * widths are the ON-DISK contract, measured on a live 2.11BSD PDP-11/70 and
 * pinned by toolchain/tests/M37/pdplayout.c; do not "fix" one to a friendlier
 * type without changing the format.
 *
 * fcc widths, MEASURED rather than assumed: short 2, int 2, long 4, and
 * POINTERS 4.  FGX2 userland is multi-bank, so a pointer carries a bank byte
 * alongside its 16-bit offset.  Every structure here is bigger than a
 * 16-bit-pointer machine would make it, which is the fact the whole VFS memory
 * budget rests on.
 */
#ifndef _FSPARAM_H_
#define _FSPARAM_H_

/* THE LINK CEILING IS THE ON-DISK TYPE'S, not a policy: ic_nlink is a signed
 * 16-bit field, so 32767 is what it can hold.  Reno's LINK_MAX is the same
 * number for the same reason. */
#define LINK_MAX        32767

#ifndef _FGX_HAVE_INO_T
#define _FGX_HAVE_INO_T
typedef unsigned short  ino_t;
#endif
/* PER-TYPE GUARDS ON THE ONES THAT OVERLAP.  src/kernel/tty/ttyparam.h and
 * src/kernel/vfs/fsparam.h each declare the scalar types their own bank needs,
 * and dev_t and off_t are in both -- so a file that needs a tty AND a uio
 * (tty_probe, and ttread when it lands) got `expected typedef name' on the
 * second declaration and could not include both.  Guarding the two that
 * overlap costs four lines and lets either header come first; merging the two
 * headers, or making one include the other, would put a bank's types in the
 * other bank's build for one caller.
 *
 * WIDENED AT UFS 2.1 TO COVER USERLAND.  src/userland/fsck is the first
 * program outside the kernel to need the on-disk format, so it includes this
 * header -- as 2.11BSD's fsck includes the kernel's h/fs.h, /usr/include/sys
 * being the same tree over there.  toolchain/include/sys/types.h declares the
 * same scalars, so every type the two share is guarded now rather than just
 * the two banks' pair, and sys/types.h sets the same _FGX_HAVE_* macros so
 * either header may come first.  KNOWN DIVERGENCE, not fixed here: userland's
 * dev_t is `short' and this one is `unsigned short'. */
#ifndef _FGX_HAVE_DEV_T
#define _FGX_HAVE_DEV_T
typedef unsigned short  dev_t;
#endif
#ifndef _FGX_HAVE_UID_T
#define _FGX_HAVE_UID_T
typedef unsigned short  uid_t;
#endif
#ifndef _FGX_HAVE_GID_T
#define _FGX_HAVE_GID_T
typedef unsigned short  gid_t;
#endif
typedef long            daddr_t;        /* userland has no daddr_t to clash */
#ifndef _FGX_HAVE_TIME_T
#define _FGX_HAVE_TIME_T
typedef long            time_t;
#endif
#ifndef _FGX_HAVE_OFF_T
#define _FGX_HAVE_OFF_T
typedef long            off_t;
#endif

#define NADDR       7           /* 4 direct + 3 indirect */

/* ======================= SIZING KNOBS =======================
 *
 * Defaults, not measured optima: the real working set is only observable in
 * use.  What is pinned is the RELATIONSHIPS -- floors that must hold and
 * ceilings that must not be crossed -- so a knob can move without the
 * conformance fixture needing an edit, while a knob moved somewhere illegal
 * fails loudly.  See toolchain/tests/M37/vfslayout.c.
 *
 * Derived from a LIVE 2.11BSD PDP-11/70, measured 2026-08-09 with `pstat -T`:
 *
 *      65/160 files        160 open-file slots, 65 in use
 *      78/176 inodes       176 in-core inode slots, 78 in use
 *      23/122 processes    122 process slots, 23 in use
 *
 * That measurement disproves the obvious rule "one vnode per open file".
 * 2.11BSD does not size its inode table that way: 122 process slots at
 * NOFILE=30 is 3660 possible descriptors, served by 176 inode slots.  The
 * table is keyed by (dev, inum), so every descriptor open on the same file
 * shares ONE entry and dup shares the file struct outright.  It covers
 * DISTINCT FILES IN USE, not descriptors, and exhaustion is a documented
 * degraded mode ("inode: table full"), not a deadlock.
 */
#define FS_MAX_FDS      30      /* = 2.11BSD NOFILE, confirmed on the machine */
/* MUST EQUAL CFG_KERNEL_NPROC, and it is CHECKED now rather than asserted in a
 * comment.  Pids run 1..NPROC (include/kernel.s:116, "slots 0..NPROC-1 and
 * pid = slot+1"), and every per-process VFS pool is indexed by pid, so a
 * VFS_NPROC below NPROC does not degrade -- it silently denies the HIGHEST pid
 * its slot.  ndslot's `pid > VFS_NPROC` returns 0 and namei fails for that
 * process alone.
 *
 * That is not hypothetical: this read 11 correctly when it was written
 * (2026-08-10), `kernel.nproc` went 11 -> 12 on 2026-08-14, and the comment
 * here kept claiming the two were equal for four days while process 12 had no
 * pathname buffer.  tools/gen_vfs_equ.py now compares them against
 * cfg/system.cfg on every build, so the next bump fails loudly instead. */
#define VFS_NPROC       32      /* = CFG_KERNEL_NPROC; checked, see above */
#define VFS_NMOUNT      14      /* mount table slots */

/* Vnode pool.  Two derivations, and the larger wins.
 *
 *   FLOOR, structural: with cwd held as a vnode (and exec NOT holding one),
 *   the pool can never go below one cwd per process plus one root per mount,
 *   because those are pinned for as long as the process or mount lives and can
 *   never be reclaimed under pressure.  32 + 14 = 46.
 *
 *   SCALED, from the machine: 176 inode slots for 122 process slots is 1.44
 *   per process, which at NPROC=32 gives 46 -- the floor exactly, since
 *   2.11BSD's ratio is dominated by processes that share a cwd and this
 *   mount table is proportionally much larger.
 *
 * So 64 is the floor plus a working set of open files (eighteen).  The pool
 * is a heap arena (VFS_POOL_BYTES, sized by tools/gen_vfs_equ.py), so the
 * size costs no bank.  A machine that runs out reports ENFILE rather than
 * wedging. */
#define VNODE_POOL      64

/* Device vnodes: the alias hash and the specinfo pool.
 *
 * NSPECINFO IS ONE PER VNODE, which is the same rule NNAMECACHE below states
 * and for a stricter reason than the cache's.  A device vnode takes a
 * specinfo in checkalias and holds it until vgone (vfs_subr.c), so EVERY
 * vnode in the pool can be holding one at once -- and exhaustion here panics
 * rather than degrading, there being no ENFILE to return: checkalias is
 * called from paths that have already committed to the vnode.  A pool smaller
 * than VNODE_POOL therefore panics on a workload the vnode layer would merely
 * recycle through, and an equal one can never be the binding constraint.
 *
 * 4.3BSD-Reno has no such pool -- its checkalias MALLOCs each specinfo -- so
 * the ceiling is FGX's and so is the obligation to keep it above the demand.
 *
 * IT WAS VFS_NMOUNT + 8, derived from "one pinned per mount plus the consoles
 * and their ttys", and `ls -l /dev' panicked the machine (apple/fgx#411): the
 * root's /dev carries 27 device nodes since the per-unit block and raw-disk
 * lists landed, a listing stats all of them in one pass, and the 23rd had
 * nowhere to go.
 *
 * SPECHSZ is Reno's 64 cut to the size of that pool.  It must stay a power of
 * two (see SPECHASH in specdev.h), and at 8 buckets for 32 possible entries
 * the chains stay short enough that vgone's walk-to-find-the-predecessor is
 * not worth a second back-link. */
#define SPECHSZ         8       /* device alias hash buckets; power of two */
#define NSPECINFO       VNODE_POOL

/* The name cache.
 *
 * NNAMECACHE is one entry per vnode, which is Reno's rule (it grows the cache
 * to desiredvnodes) and is the right shape rather than a coincidence: an entry
 * is only useful while the vnode it names is still live, so a cache larger
 * than the pool caches names for vnodes that no longer exist, and one much
 * smaller evicts entries for vnodes that are still held.  At 64 bytes an entry
 * that is 2 KB, which is the largest single thing the far bank gives the VFS
 * after the buffer arena -- and the arena is heap, so this one is real.
 *
 * NCHASH must stay a power of two: the index is (ni_hash & (NCHASH - 1)).  A
 * bucket is a `struct nchash`, TWO POINTERS, not a whole entry -- see namei.h
 * -- so 16 buckets cost 128 bytes and not a kilobyte. */
#define NNAMECACHE      VNODE_POOL
#define NCHASH          16      /* name hash buckets; power of two */

/* The open-file table (UFS 1.2c).  Derived the same two ways VNODE_POOL was,
 * and here the two AGREE rather than one governing:
 *
 *   SCALED, from the machine: 160 file slots for 122 process slots is 1.31 per
 *   process, which at NPROC=32 gives 42.
 *
 *   FLOOR, structural: a login shell's three standard descriptors are INHERITED
 *   rather than reopened -- they are one set of file structs shared down the
 *   whole process tree, so they cost 3 once and not 3 per process.  What is
 *   pinned per process is whatever it opened for itself, so the floor is 3 + 32
 *   = 35.
 *
 * Both land near 40, and 64 is that plus a working set -- the same margin
 * VNODE_POOL carries, and the two are equal for a reason worth stating: two
 * independent open(2)s of one path are TWO file structs and ONE vnode, so
 * files can exceed vnodes; but dup and fork share a file struct outright, so
 * they can also fall well below.  The measured machine had 65 files against 78
 * inodes in use, which is the second effect winning.  Equal sizing is the
 * honest answer to a ratio that moves in both directions, and exhaustion is a
 * documented degraded mode -- falloc returns ENFILE -- not a wedge.
 *
 * FS_MAX_FDS is the per-process descriptor limit and is NOT this: 32 processes
 * at 30 descriptors is 960 possible descriptors served by 64 file structs, the
 * same over-subscription 2.11BSD runs (3660 served by 160).  The table and the
 * per-process descriptor arrays are one heap arena (VFS_FILE_BYTES), so the
 * size costs no bank. */
#define NFILE           64

/* Mount-point name length.  Reno's MNAMELEN is 90 and statfs carries TWO of
 * them plus nine spare longs -- 216 bytes of a 250-byte struct mount, times 14
 * mounts.  FGX's existing mount table already uses 16-byte names; 32 leaves
 * room for a nested mount point without putting 3 KB of mostly-blank names in
 * the kernel. */
#define MNAMELEN        32

/* Buffer pool.  The knob most likely to need turning, and the one where FGX's
 * own measurements contradict the obvious instinct: the existing 24-slot block
 * cache was found SCAN-bound rather than capacity-bound, and enlarging it made
 * it SLOWER.  That finding does not carry over unexamined, because it was a
 * property of a LINEAR SCAN.  2.11BSD's buffer pool is hash-chained
 * (binshash/bremhash in its sys/buf.h), so a lookup does not walk the pool and
 * growth is affordable in a way it was not before.  Both facts belong next to
 * this number or the next person re-learns one of them. */
#define NBUF            16
#define FS_BLKSIZE      1024    /* 2.11BSD fs block; measured on the machine */

/* lblkno and blkoff -- an offset's block, and its position within that block.
 *
 * 2.11BSD usr/sys/h/fs.h:95-98, INCLUDING ITS COMMENT, which is the reason
 * they exist rather than a note about them:
 *
 *     The following macros optimize certain frequently calculated
 *     quantities by using shifts and masks in place of divisions
 *     modulos and multiplications.
 *
 * IT IS NOT A MICRO-OPTIMISATION ON THIS TARGET.  A uio offset is an off_t,
 * so `off / FS_BLKSIZE` is a 32-BIT DIVIDE, and fcc has no divide instruction
 * to emit -- it calls a software routine, once per block of every read and
 * every write, with the modulo calling a second one.  ufs_bmap.c's header
 * already states the same thing about the indirect-level arithmetic and takes
 * 2.11BSD's shift there for the same reason; these are the rest of the sites.
 * Every one of them divides by FS_BLKSIZE, which is a power of two, so the
 * shift and the mask are EXACT and not an approximation of the division.
 *
 * THE CASTS ARE THE CALLER'S, deliberately.  These carry the type they are
 * given -- an off_t in, an off_t out -- because a cast inside the macro would
 * silently narrow a 32-bit offset at a call site that meant to keep it, and
 * the sites that want an int say so themselves.
 */
#define FS_BSHIFT       10      /* log2(FS_BLKSIZE) */
#define FS_BMASK        1023L   /* FS_BLKSIZE - 1 */
#define lblkno(loc)     ((loc) >> FS_BSHIFT)
#define blkoff(loc)     ((loc) & FS_BMASK)

/* The ceiling every pool is really sized against.  A 65816 bank is 64 KB and
 * the VFS pools live in a module bank, so the question is not "is this small"
 * but "does the set of them still fit one bank with room for the code".
 *
 * BOTH ARE LONG, and the fixture's budget arithmetic casts to long, because
 * fcc's int is 16 bits and these sums exceed it.  Written in int arithmetic a
 * pool of 100 buffers computes 100 * 1024 = 102400, which wraps to -28672 and
 * compares happily against a BANK_SIZE that is itself 0 -- passing for every
 * pool large enough to be worth checking. */
#define BANK_SIZE       65536L
#define VFS_TABLE_MAX   32768L

/* No device.  BSD spells this (dev_t)-1; dev_t is 16 bits here. */
#define NODEV           0xFFFF

/* The major/minor device constructing and busting macros, 2.11BSD's
 * (usr/sys/h/types.h:17-23): the major is the high byte and indexes bdevsw[],
 * the minor is the low byte and is the driver's unit.  Guarded, as the types
 * above are, because toolchain/include/sys/types.h defines the first two
 * identically and fsck includes both. */
#ifndef major
#define major(x)        ((int)(((int)(x) >> 8) & 0377))
#define minor(x)        ((int)((x) & 0377))
#endif
#ifndef makedev
#define makedev(x, y)   ((dev_t)(((x) << 8) | (y)))
#endif

/* The block majors, the rows of bdevsw[] in bio_strategy.c.  NBLKDEV is
 * 2.11BSD's nblkdev as a constant, since spec_open (ufsdir.mod) tests it and
 * module C cannot read another bank's variable.  /dev's nodes are minted with
 * these (tools/ninja/gen.py), so a renumbering is a new image. */
#define SD_MAJOR        0       /* SmartPort disks */
#define RAM_MAJOR       1       /* the Control Panel RAM disk */
#define NBLKDEV         2

/* Errno values kernel C needs.  It links no libc, so it cannot include
 * errno.h; these must stay equal to their toolchain/include/errno.h
 * counterparts, which are the values BSD has always used.
 *
 * A SECOND COPY OF A NUMBER IS A THING THAT DRIFTS, so this list is kept as
 * short as the code actually needs rather than mirroring errno.h wholesale,
 * and tools/check_kernelc_errno.py compares every entry against errno.h on
 * every build. */
#define EIO             5       /* I/O error */
#define ENXIO           6       /* no such device or address */
#define EBADF           9       /* bad file descriptor */
#define ENOTBLK         15      /* block device required -- getmdev, 1.8b-1 */
#define ENODEV          19      /* no such filesystem type -- mount(2)'s
                                 * refusal of a type it cannot dispatch, 1.8b-2 */
#define EBUSY           16      /* device or resource busy */
#define ENOTDIR         20      /* not a directory */
#define ENOTTY          25      /* inappropriate ioctl for device */
#define ENOENT          2       /* no such file or directory */
#define ENFILE          23      /* file table overflow */
#define EINVAL          22      /* invalid argument */
#define ENOMEM          12      /* out of memory -- and sysctl_int's refusal of
                                 * an `oldp' buffer too small to hold the leaf
                                 * (2.11BSD kern_sysctl.c) */
#define ENAMETOOLONG    63      /* file name too long */
#define ENOTSOCK        38      /* socket operation on non-socket -- unp_nameop's
                                 * refusal of a name that is not a VSOCK */
#define EADDRINUSE      48      /* address already in use -- unp_nameop's
                                 * refusal of a name that already exists.
                                 * Upstream's comment marks adopt-and-wakeup as a
                                 * FIFO-style improvement it did not make */
#define ECONNREFUSED    61      /* connection refused -- a VSOCK node with no
                                 * live socket behind it, which is the ordinary
                                 * case after a restart because close(2) does not
                                 * unlink the name */
#define EISDIR          21      /* is a directory */
#define EXDEV           18      /* cross-device link -- rename(2)'s check.  18
                                 * agrees with include/errno.s:55 and
                                 * toolchain/include/errno.h:40, which is the
                                 * rule every errno in this header follows. */
#define EFAULT          14      /* bad address -- uiomove's refusal of a USER
                                 * segment while there is no copyin/copyout to
                                 * reach one safely.  See kern_subr.c. */
#define EROFS           30      /* read-only file system -- what a UFS vnode op
                                 * that MODIFIES returns while the mount is
                                 * forced read-only.  Distinct from ENOSYS on
                                 * purpose: it is the true answer, not a
                                 * placeholder.  ufs_vnops.c. */
#define ENOSYS          78      /* function not implemented -- what a vfsops
                                 * slot returns while its deliverable is still
                                 * ahead of it (ufs_root, ufs_mount). */
#define EFBIG           27      /* file too large -- ufs_bmap's refusal of a
                                 * logical block past the triple-indirect
                                 * reach, and of a negative one. */
#define ENOSPC          28      /* no space left on device -- what the 2.11BSD
                                 * allocator reports for both a drained free
                                 * list and a drained i-list.  ufs_alloc.c. */
#define EPERM           1       /* operation not permitted -- what ufs_setattr
                                 * answers for chown, chmod and the user flags
                                 * word (1.12b).  Each needs a credential to
                                 * decide whether the caller MAY, and this tree
                                 * has none until 2.6; EPERM is the honest
                                 * answer from a filesystem that cannot tell,
                                 * where ignoring the field would let a caller
                                 * believe it had taken effect. */
#define EACCES          13      /* permission denied -- ufs_access's refusal
                                 * (2.6).  Agrees with include/errno.s:16 and
                                 * toolchain/include/errno.h:19, which is this
                                 * header's rule.  DISTINCT FROM EPERM above:
                                 * EPERM is "you are not allowed to do this at
                                 * all", which is what setattr answers for an
                                 * ownership change; EACCES is "the mode bits
                                 * say no", which is what a permission check
                                 * answers.  Reno's ufs_access returns this
                                 * one. */
#define EEXIST          17      /* file exists -- checkpath's refusal when a
                                 * rename would make a directory its own
                                 * ancestor (1.12c). */
#define EMLINK          31      /* too many links -- ufs_link's refusal at
                                 * LINK_MAX.  i_nlink is a 16-bit signed field
                                 * on disk, so the ceiling is the type's and
                                 * not a policy. */
#define ELOOP           62      /* too many levels of symbolic links --
                                 * namei's refusal at MAXSYMLINKS.  62 in both
                                 * 2.11BSD and Reno. */
#define ENOTEMPTY       66      /* directory not empty -- rmdir's refusal.
                                 * 2.11BSD and Reno agree on 66. */
#define ENOTSUP         45      /* operation not supported -- vn_open's refusal
                                 * of a VSOCK.  BOTH UPSTREAMS SPELL THIS
                                 * EOPNOTSUPP (Reno sys/errno.h:84, 2.11BSD
                                 * h/errno.h:66) and this tree's errno.h spells
                                 * it ENOTSUP, but the NUMBER is 45 in all
                                 * three -- so a caller sees upstream's value
                                 * and only the name is local. */
#define EAGAIN          11      /* resource temporarily unavailable -- the
                                 * errno.h number for BSD's EWOULDBLOCK, which
                                 * is flock(2)'s LOCK_NB answer (vn_lock) */
#define EWOULDBLOCK     EAGAIN
#define EINTR           4       /* interrupted system call -- a signal ended
                                 * vn_lock's wait for a conflicting lock */
#define ETXTBSY         26      /* text file busy -- vn_writechk's refusal of a
                                 * write to a vnode wearing VTEXT.  26 in both
                                 * upstreams and in errno.h.  NOTHING SETS
                                 * VTEXT in this tree, so the arm cannot fire
                                 * yet; vfs_vnops.c says so at the site. */
#define EMFILE          24      /* too many open files -- PER PROCESS.  The
                                 * table-wide exhaustion is ENFILE above, and
                                 * ufalloc/falloc return one each: mixing them
                                 * tells a user to close files when the machine
                                 * is what ran out, or the reverse. */
#define ESPIPE          29      /* illegal seek -- vfs_lseek's refusal of a
                                 * descriptor that is not a vnode.  It is what
                                 * a pipe or socket says when asked for a seek
                                 * pointer it does not have, and the shell
                                 * depends on the distinction from EBADF. */

/* PATH AND COMPONENT LIMITS, for namei.
 *
 * MAXPATHLEN is 128.  This DIVERGES from both upstreams: 2.11BSD has 256
 * (vendor/2.11BSD/usr/sys/h/param.h) and Reno has PATH_MAX, 1024
 * (vendor/4.3BSD-Reno/sys/param.h).  The reason is bank space: every path
 * staging buffer is sized to it -- _Sys_PathBuf/_Sys_LinkBuf in syscall.s, and
 * the core-bank landing pad for far-bank paths, FS_FARPATH_MAX 127 chars plus
 * the NUL (include/memmap.s) -- and those buffers live in 64 KB banks.  The
 * limits must agree, or the narrowest buffer silently decides the real one.
 *
 * MAXNAMLEN is 63, MEASURED rather than chosen: it is what fgxfs.py found on
 * the real 2.11BSD volume.  Note it is deliberately LONGER than the name cache
 * holds (NCHNAMLEN, 31) -- see namei.h for why the cache declines the tail
 * rather than growing to meet it. */
#define MAXPATHLEN      128

/* MAXSYMLINKS -- how many links one path resolution may follow before it is
 * called a loop.  8 in both 2.11BSD's and Reno's sys/param.h; the value matters less than
 * having one: `ln -s a b; ln -s b a; cat a` is otherwise a kernel that does not
 * come back. */
#define MAXSYMLINKS     8
#define MAXNAMLEN       63

/* NAMEIDATA SLOTS PER PROCESS (UFS 1.2).
 *
 * WHY THIS EXISTS AT ALL.  namei's pathname buffer used to be the CALLER's,
 * because 1.6b had no per-process storage to hang one off and would not put a
 * static inside namei -- a shared work area crossing a sleep is apple/fgx#41's
 * shape, and every VFS wait sleeps.  This is that storage.
 *
 * WHY TWO, AND NOT ONE.  Reno keeps ONE nameidata in the u-area, and rename(2)
 * needs a SECOND one live at the same time (vfs_syscalls.c:1420, `struct
 * nameidata tond`, a kernel-stack local).  nddup() copies only the walk's
 * context -- cdir, rdir, cred (vfs_subr.c:180) -- so the second walk allocates
 * its OWN pathname buffer and the two are concurrent in full.  FGX cannot put
 * the second on the kernel stack: that stack is 256 bytes for everything, and
 * kernel C here holds no local arrays or structs by the same 2.11BSD rule that
 * puts large buffers in the u-area.  So both slots are per-process storage.
 *
 * WHY NOT RENO'S PER-CALL MALLOC.  Reno gets its buffer from
 * MALLOC(M_NAMEI, M_WAITOK) per call and frees it on the way out, because at
 * MAXPATHLEN 1024 a static per process is prohibitive on a VAX.
 *
 * THAT ROUTE IS AVAILABLE HERE -- say so plainly, because an earlier draft of
 * this comment claimed kernel C had no allocator and it was simply wrong.
 * KSVC_KMALLOC is a module service, vfs.mod's own asm already calls it twice
 * to build these very arenas, and a C-callable shim is a few lines.  It is
 * also SAFER here than in Reno in one respect: Reno's M_WAITOK can block
 * waiting for memory, which would be a sleep inside namei, and FGX's Kmalloc
 * cannot sleep at all (src/kernel/libc/alloc.s -- a first-fit free-list walk
 * that returns ENOMEM rather than waiting).
 *
 * So this is a DELIBERATE DEVIATION ON COST, not an adaptation forced by a
 * missing primitive.  What per-call allocation would buy: 3,960 bytes of heap
 * back, and a buffer whose lifetime is the CALL, as Reno's is.  What it would
 * cost: a free-list walk on every path resolution -- open, stat, exec, chdir,
 * the most-travelled routine in the kernel -- and an ENOMEM failure path
 * inside namei that Reno does not have, since M_WAITOK cannot fail.  At
 * MAXPATHLEN 128 the storage is cheap enough that neither is worth buying.
 *
 * Revisit if MAXPATHLEN grows, if NPROC grows, or if the buffer's system
 * lifetime is ever found to matter -- a pointer INTO a slot's buffer
 * (ni_ptr, ni_next) is valid only until that process's next walk, where in
 * Reno it dies with the call.  Nothing retains such a pointer today: the name
 * cache COPIES the component (vfs_cache.c), and every other reader is inside
 * the walk.
 *
 * ONE SLOT, ONE BUFFER IS NOT ENOUGH FOR SYMLINKS, and that is known now
 * rather than later.  Reno's symlink expansion needs TWO MAXPATHLEN buffers
 * live at once whenever path remains after the link (vfs_lookup.c:287-321):
 * it mallocs a second, reads the link into it, copies the un-walked remainder
 * out of the OLD buffer behind it, and only then frees the old and swaps.
 * In-place is the degenerate case only, where the symlink is the last
 * component.  So the slice that lands symlinks must choose: a second scratch
 * buffer per slot (+MAXPATHLEN each), a kmalloc for the transient, or an
 * in-place algorithm Reno does not use.  Nothing can produce a VLNK vnode yet,
 * so this is a design note, not a defect.
 *
 * A POOL smaller than NPROC*2 is a different matter and stays rejected: it
 * needs a wait when it comes up empty, and that wait IS a sleep inside namei
 * -- the exact hazard the first paragraph exists to avoid.  Indexing by pid
 * cannot fail and cannot block. */
#define VFS_NDPERPROC   2

#endif /* _FSPARAM_H_ */

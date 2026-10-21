/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno ufs/ufs_vfsops.c
 *   Ported from ufs/ufs_vfsops.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 *
 *   TWO UPSTREAMS AND TWO NOTICES, because this file has both and one line
 *   cannot say so.  `ufs_mount' and `getmdev' are Reno's, above; `ufs_statfs'
 *   is 2.11BSD's `statfs1' and `ufs_mountfs' follows its `mountfs' -- Reno
 *   computes free space from a cylinder-group summary a 2.11BSD volume does
 *   not have, which docs/PROVENANCE.md records at length.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* ufs_vfsops.c -- attaching a filesystem.  UFS 1.8a.
 *
 * THE SUPERBLOCK AS BYTES MOVED TO ufs_sb.c AT 1.11a -- decode, encode and
 * validate, everything that knows the PDP-11 byte order and touches nothing
 * else.  See that file on why: a host fixture #includes it to test one
 * decoder, and while the two shared a file every function added here became a
 * stub in that fixture.
 *
 * What is left is the MOUNT, and the cut is "does it touch a device": the two
 * superblock I/O routines below read and write through the buffer cache, the
 * vfsops attach and describe a filesystem.
 */
extern int          ufs_iflushall();   /* ufs_inode.c -- update()'s walk */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"
#include "ufs_fs.h"
#include "mount.h"
#include "vfsops.h"
#include "ufsmount.h"
#include "inode.h"
#include "specdev.h"
#include "namei.h"

extern long kern_time();    /* kern_time.c, apple/fgx#167 */
extern int  bread();
extern int  bwrite();
extern void brelse();
extern void vrele();
extern int  namei();     /* vfs_lookup.c -- getmdev's whole body is one */
extern int  iget();
extern void ufs_ihashinit();
extern int  ufs_statfs();
extern int  vflush();           /* vfs.mod, through vfs_import.s -- 1.8b-3c */
extern int  vfs_setvfsops();    /* vfs.mod, through vfs_import.s -- vfssw[] */
extern struct vfsops ufs_vfsops;

/* From ufs_sb.c -- the byte-order half.  ufs_sbread and ufs_sbupdate are the
 * only callers here; ufs_alloc.c takes the fblk pair directly. */
extern void ufs_sbdecode();
extern void ufs_sbencode();
extern int  ufs_sbvalid();


/* ufs_sbread -- read and validate the superblock of the filesystem on devvp.
 *
 * The buffer is released either way.  Reno's mountfs holds the superblock
 * buffer for the life of the mount and copies out of it; that belongs with
 * ufs_mount at 1.8, when there is a `struct mount` to hang the copy off.  Here
 * the caller supplies the destination and the buffer's life ends with the
 * call, which is the shape a probe wants and the shape 1.8 will wrap.
 */
int
ufs_sbread(devvp, sb, volblocks)
struct vnode *devvp;
struct ufs_sb *sb;
daddr_t volblocks;
{
    struct buf *bp;
    int error;

    error = bread(devvp, (daddr_t)UFS_SBLOCK, &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    ufs_sbdecode(bp->b_addr, sb);
    brelse(bp);

    if (!ufs_sbvalid(sb, volblocks))
        return (EINVAL);
    return (0);
}


/* ufs_sbupdate -- write the in-core superblock back.  UFS 1.10b.
 *
 * READ-MODIFY-WRITE, for the reason ufs_sbencode gives: the on-disk superblock
 * has fields this port does not carry, and they only survive if the block we
 * encode into is the one the disk currently holds.
 *
 * SB_TIME IS STAMPED HERE, beside the fs_fmod clear, which is where 2.11BSD's
 * balloc puts it: `fs->fs_fmod = 0; fs->fs_time = time.tv_sec;`
 * (usr/sys/sys/ufs_alloc.c:78-79).  It was not, until apple/fgx#167 gave
 * kernel C a clock -- and the consequence of not stamping it was not
 * theoretical: the campaign's own gate is "2.11BSD's own fsck clean on the
 * same image", and a volume carrying the update time of whoever last wrote it
 * with a working clock is a difference that machine can see.
 *
 * A CLOCK THAT CANNOT BE READ LEAVES THE FIELD ALONE.  kern_time returns 0 for
 * an unset RTC, and writing that would date the volume to 1970 -- strictly
 * worse than the platter's own value, which at least came from a machine that
 * knew what time it was.  Upstream has no such case because a PDP-11 kernel
 * cannot be running without `time` having been set.
 *
 * Synchronous.  2.11BSD picks bwrite or bdwrite off MNT_ASYNC, and the mount
 * flags that would carry it arrive with `struct mount` at 1.8; until then the
 * safe half of that choice is the one to take, since the whole point of
 * writing the superblock during a refill is that the free-list head on disk
 * must not be allowed to lag the blocks already handed out. */
int
ufs_sbupdate(devvp, sb)
struct vnode *devvp;
struct ufs_sb *sb;
{
    struct buf *bp;
    int error;
    long now;

    now = kern_time();
    if (now != 0L)
        sb->sb_time = now;
    error = bread(devvp, (daddr_t)UFS_SBLOCK, &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    ufs_sbencode(sb, bp->b_addr);
    return (bwrite(bp));
}


/*============================================================================
 * THE MOUNT.  UFS 1.8a.
 *
 * Everything above this point is the FORMAT: read a superblock, decode it,
 * decide whether it describes a filesystem.  What follows attaches one to the
 * system -- a `struct mount` the VFS understands, with a `struct ufsmount`
 * hanging off it that only UFS does.
 *
 * WHY 1.8 CAME AFTER 1.10 AND NOT BEFORE IT.  The plan ordered mount first;
 * It was reversed so that 1.9's fgxfs could act as an independent oracle
 * before any of this existed, on the grounds that a mount(2) registering an
 * empty vfssw[] is untestable.  That was right, and it left one dependency
 * pointing backwards: Reno's iget reaches through the mount for both the device
 * and the superblock, so 1.11's in-core inode wants what this file now builds.
 *
 * WHICH IS ALSO WHY ufs_root IS A STUB HERE.  Reno's mountfs finishes by
 * calling ufs_root to get the root vnode, and ufs_root calls iget -- so mount
 * and iget are mutually recursive across the deliverable boundary.  The cut is
 * made here: 1.8a builds the mount from a device vnode, and 1.11a's iget uses
 * it to produce the root.  A stub that returns ENOSYS rather than a null slot,
 * because a null function pointer in a vector is a slot somebody eventually
 * calls.
 *============================================================================
 */

/* ufs_mountfs -- attach the filesystem on devvp to mp.  Reno's ufs_mountfs.
 *
 * THE CALLER OWNS BOTH STRUCTURES, where Reno mallocs the ufsmount here.  That
 * is this tree's convention rather than a shortcut: kernel C has no allocator
 * -- there is no kc_malloc, by design -- so every arena in the VFS is carved by
 * assembly at module load and handed to C, exactly as vfs_init(arena) is.
 * 1.8b's mount(2) will carve a small mount table the same way.
 *
 * IT DOES NOT HOLD THE SUPERBLOCK BUFFER, and 1.10a's ufs_sbread left a note
 * saying it would: "Reno's mountfs holds the superblock buffer for the life of
 * the mount and copies out of it; that belongs with ufs_mount at 1.8, when
 * there is a struct mount to hang the copy off."  The answer turned out to be
 * that there is nothing to hold.  Reno keeps the buffer because its in-core
 * superblock IS the on-disk bytes; ours is decoded into um_sb, so the decode is
 * the copy and the buffer's life can end with the read.
 */
/* ufs_devname -- write "/dev/<driver><unit>" into a MNAMELEN buffer.
 *
 * THE NAME MATCHES THE NODE: the major names the driver, as bdevsw does, and
 * the minor is its unit -- `sd' for a SmartPort disk, `ram' for the RAM disk
 * and `cd' for a CD-ROM, the names tools/ninja/gen.py mints.  2.11BSD would spell the same
 * thing `ra0a' or `hk0a' -- controller, unit, partition -- and FGX has neither
 * controllers nor partitions to name.
 *
 * ONE DIGIT, because a driver here has at most eight units; anything out of
 * range, or a major with no name, gets '?' rather than a wrong character -- an
 * unreadable name is better than a plausible one. */
static void
ufs_devname(buf, dev)
char *buf;
dev_t dev;
{
    int unit, n;

    buf[0] = '/'; buf[1] = 'd'; buf[2] = 'e'; buf[3] = 'v'; buf[4] = '/';
    n = 5;
    if (major(dev) == SD_MAJOR) {
        buf[n++] = 's'; buf[n++] = 'd';
    } else if (major(dev) == RAM_MAJOR) {
        buf[n++] = 'r'; buf[n++] = 'a'; buf[n++] = 'm';
    } else if (major(dev) == CD_MAJOR) {
        buf[n++] = 'c'; buf[n++] = 'd';
    } else {
        buf[n++] = '?';
    }
    unit = minor(dev);
    buf[n++] = (unit <= 9) ? (char)('0' + unit) : '?';
    buf[n] = 0;
}

int
ufs_mountfs(devvp, mp, ump)
struct vnode   *devvp;
struct mount   *mp;
struct ufsmount *ump;
{
    int error;
    int i;

    /* Read and VALIDATE before anything is wired up.  ufs_sbvalid is the same
     * consistency check fgxfs's fsck phase 0 makes, deliberately -- the host
     * tool and the kernel must agree what a valid volume is, or one will mount
     * what the other calls corrupt.  volblocks 0 because the device's true
     * size is not known here; 1.8b's mount(2) can pass it. */
    error = ufs_sbread(devvp, &ump->um_sb, (daddr_t)0);
    if (error)
        return (error);

    ump->um_mountp = mp;
    ump->um_devvp  = devvp;
    ump->um_dev    = devvp->v_rdev;

    /* AND THE DEVICE IS MARKED AS CARRYING A MOUNT, which is Reno's
     * `devvp->v_specflags |= SI_MOUNTEDON' (ufs/ufs_vfsops.c:285).
     *
     * WITHOUT IT mountedon() CANNOT ANSWER, and mountedon() is the whole of
     * spec_open's VBLK arm: a block device with a filesystem on it must not
     * also open as a raw device, because writing through the second name
     * corrupts the mount underneath itself with no error anywhere.  The test
     * and its alias walk were ported with specfs; the flag they read was
     * never raised, so the refusal has never fired and `/dev/sd0' has opened
     * on a live root like any other file.
     *
     * IT GOES ON THE VNODE THE MOUNT CAME THROUGH and is found through the
     * others: checkalias gives every later name for the same device its own
     * vnode on one specinfo chain and marks the set VALIASED, which is the
     * chain mountedon() walks.  So the root's bdevvp carries the flag and an
     * `open("/dev/sd0")' that reaches iget finds it. */
    devvp->v_specflags |= SI_MOUNTEDON;

    mp->mnt_data   = (char *)ump;
    mp->mnt_op     = &ufs_vfsops;

    /* THE CALLER'S MOUNT FLAGS STAND, WHICH THEY DID NOT USED TO.  This forced
     * `mp->mnt_flag |= MNT_RDONLY' on every mount, and said why: "the write
     * path is 1.12; until then a writable UFS mount would be a promise the
     * filesystem cannot keep".  1.12 LANDED -- ufs_write, ufs_maknode and
     * itrunc are all here and ufs_wprobe asserts them against a scratch
     * volume -- so the promise can be kept and the force is what stood
     * between a mounted root and `vi'.
     *
     * IT WAS ALSO HALF-ENFORCED, WHICH IS WHY LIFTING IT IS A FIX AND NOT A
     * RELAXATION.  namei was missing Reno's two EROFS gates, so MNT_RDONLY
     * governed only vn_open's non-FCREAT arm (through vn_writechk): a CREATE
     * went through and a later open-for-write of the same name came back
     * EROFS.  Both gates are ported now (vfs_lookup.c), so the flag means
     * what it says in both directions -- and a caller that wants a read-only
     * mount sets it and is now actually obeyed.
     *
     * Reno's ufs_mount reads the flag the mount(2) caller set rather than
     * writing one; this now matches. */

    /* AND THE MOUNT FLAG IS WHAT sb_ronly IS SET FROM, which is both trees'
     * line and was missing:
     *
     *      int ronly = (mp->mnt_flag & MNT_RDONLY) != 0;   -- Reno :209
     *      ...
     *      fs->fs_ronly = ronly;                           -- Reno :248
     *      if (ronly == 0)
     *              fs->fs_fmod = 1;                        -- Reno :249-250
     *
     * and `fs->fs_ronly = (ronly != 0)' at 2.11BSD ufs_mount.c:224.  Without
     * it sb_ronly was only ever the byte the superblock happened to carry --
     * zero on every volume fgxfs writes -- so iupdat's guard could not fire
     * and a read-only mount still had its inode timestamps written back.  Only
     * namei's EROFS gates stood, which stop a caller from asking and not a
     * write the filesystem does on its own behalf.
     *
     * IT IS ALSO WHAT MAKES `mount -u' MEAN ANYTHING: the update arm clears
     * sb_ronly to go read-only to read-write, and a flag nothing ever set is
     * a transition with nothing to make.
     *
     * fs_fmod ON A WRITABLE MOUNT is Reno's next line and has the same reason
     * as boot(): the superblock gets written back so its date is current.  The
     * flush is ufs_sbupdate's, which already tests sb_fmod. */
    ump->um_sb.sb_ronly = (mp->mnt_flag & MNT_RDONLY) != 0;
    if (ump->um_sb.sb_ronly == 0)
        ump->um_sb.sb_fmod = 1;

    /* AND THE CLEAN FLAG IS CARRIED FORWARD AND THEN CLEARED, 2.11BSD update
     * #456's two lines in mountfs:
     *
     *      if (fs->fs_flags & MNT_CLEAN) flags |= MNT_WASCLEAN;
     *      fs->fs_flags = flags;
     *
     * The assignment is the half that is easy to read as bookkeeping and is
     * not: `flags' is the MOUNT flags, which never contain MNT_CLEAN, so
     * mounting a clean volume MARKS IT DIRTY -- and the sync below is what puts
     * that on the platter before anything else touches it.  A machine that
     * loses power mid-session then comes back to a volume that says "check me",
     * which is the whole point.
     *
     * MNT_WASCLEAN IS THE MEMORY OF WHAT IT WAS, and it is what ufs_unmount
     * tests before marking the volume clean again: a filesystem that came up
     * DIRTY must not be declared clean by unmounting it, only by fsck.
     *
     * ON A READ-ONLY MOUNT NOTHING IS WRITTEN, because sb_fmod is left alone
     * above and the sync below tests it.  That is correct rather than a
     * shortcut -- a read-only mount cannot dirty the volume, so the on-disk
     * clean flag should survive it.  It is also what lets a root mounted
     * read-only at boot still read as clean to fsck. */
    if (ump->um_sb.sb_flags & MNT_CLEAN)
        mp->mnt_flag |= MNT_WASCLEAN;
    ump->um_sb.sb_flags = (unsigned short)(mp->mnt_flag & 0xFFFFL);
    if (ump->um_sb.sb_fmod)
        (void)ufs_sbupdate(devvp, &ump->um_sb);

    /* f_mntfromname -- THE DEVICE, DERIVED FROM THE DEVICE.
     *
     * 4.3BSD-Reno sets this in two places and neither is here: ufs_mountroot
     * writes the literal ROOTNAME ("root_device", ufs/ufs_vfsops.c:74) because
     * a boot mount has no path to copy, and ufs_mount copyinstr's the caller's
     * args.fspec (:186).  FGX has no mount(8) supplying an fspec and, until
     * 2026-09-05, no block node for the boot volume either -- so this carried
     * ROOTNAME, and the commit that added it said "when a block node for the
     * boot volume exists, it goes here".  /dev/sd0 exists now
     * (tools/ninja/gen.py, ROOT_BLKNODE).
     *
     * IT IS BUILT FROM um_dev RATHER THAN SPELLED, which is the whole reason
     * this is better than the literal it replaces.  The unit is the one the
     * mount actually used -- devvp->v_rdev, three lines up -- so the name in
     * df's Filesystem column cannot disagree with the device the filesystem is
     * on.  A second copy of "sd0" here would be a second authority for a fact
     * the mount already holds, which is apple/fgx#114's whole subject.
     *
     * f_mntonname IS THE CALLER'S AND IS NOT SET HERE.  It was, for one
     * commit, hardcoded to "/" -- which is right for root_mount and WRONG for
     * every other caller: dev_mount and mount(2) both reach this function and
     * neither mounts on the root.  Reno puts the mount point in ufs_mount,
     * which receives `path'; the two boot mounts here call ufs_mountfs
     * directly and set their own.  Left zeroed, so a caller that forgets shows
     * an empty column rather than a confident lie. */
    for (i = 0; i < MNAMELEN; i++) {
        mp->mnt_stat.f_mntonname[i]   = 0;
        mp->mnt_stat.f_mntfromname[i] = 0;
    }
    ufs_devname(mp->mnt_stat.f_mntfromname, ump->um_dev);

    return (ufs_statfs(mp, &mp->mnt_stat));
}


/* ufs_statfs -- the numbers `df` prints.
 *
 * THE MAPPING IS 2.11BSD'S OWN, not Reno's, and this is the one place where
 * taking Reno's code would have produced pure nonsense rather than a subtle
 * error.  Reno computes free space from the cylinder-group summary --
 * `fs_cstotal.cs_nbfree * fs_frag + cs_nffree` -- and a 2.11BSD volume has no
 * cylinder groups and no fragments at all.
 *
 * So this is statfs1 from vendor/2.11BSD/usr/sys/sys/ufs_syscalls2.c:
 *
 *      sfsp->f_blocks = fs->fs_fsize - fs->fs_isize;
 *      sfsp->f_bfree  = fs->fs_tfree;
 *      sfsp->f_bavail = fs->fs_tfree;
 *      sfsp->f_files  = (fs->fs_isize - 2) * INOPB;
 *      sfsp->f_ffree  = fs->fs_tinode;
 *
 * f_bavail EQUALS f_bfree, which is worth pointing at because Reno's does not:
 * FFS reserves fs_minfree percent for root and reports the difference, and
 * 2.11BSD has no such reserve.  A df that showed a gap here would be inventing
 * one.
 *
 * `- 2` in f_files is the i-list's own offset, not a fudge: the list starts at
 * block 2, so isize-2 is its length in blocks and INOPB inodes fit in each.
 *
 *----------------------------------------------------------------------------
 * THE NAME-COPY TAIL IS RENO'S AND WAS MISSING UNTIL 2026-09-05.  Upstream
 * ends (4.3BSD-Reno ufs/ufs_vfsops.c:508-513):
 *
 *      if (sbp != &mp->mnt_stat) {
 *              bcopy(mp->mnt_stat.f_mntonname,   &sbp->f_mntonname[0],   MNAMELEN);
 *              bcopy(mp->mnt_stat.f_mntfromname, &sbp->f_mntfromname[0], MNAMELEN);
 *      }
 *
 * and the four lines were dropped when the body was taken from 2.11BSD's
 * statfs1 -- which has no such tail because 2.11BSD keeps the two names in a
 * SEPARATE `struct xmount' mapped in at segment 5, and its statfs1 copies them
 * from there instead (usr/sys/sys/ufs_syscalls2.c:78-81).  Neither half was
 * wrong on its own; taking the body from one tree and the interface from the
 * other lost the seam between them.
 *
 * IT WAS LATENT BECAUSE THIS HAD EXACTLY ONE CALLER, `ufs_mount' above, which
 * passes &mp->mnt_stat -- the arm upstream SKIPS.  statfs(2) is the first
 * caller to pass anything else, and without the tail it would report the free
 * space of the right filesystem under a blank name.
 */
int
ufs_statfs(mp, sbp)
struct mount   *mp;
struct statfs  *sbp;
{
    struct ufsmount *ump;
    struct ufs_sb   *sb;
    int              i;

    ump = VFSTOUFS(mp);
    sb  = &ump->um_sb;

    sbp->f_type   = MOUNT_UFS;
    sbp->f_flags  = (short)(mp->mnt_flag & MNT_VISFLAGMASK);
    sbp->f_fsize  = (long)FS_BLKSIZE;
    sbp->f_bsize  = (long)FS_BLKSIZE;
    sbp->f_blocks = sb->sb_volblocks - (daddr_t)sb->sb_isize;
    sbp->f_bfree  = sb->sb_tfree;
    sbp->f_bavail = sb->sb_tfree;
    sbp->f_files  = ((long)sb->sb_isize - 2L) * (long)INOPB;
    sbp->f_ffree  = (long)sb->sb_tinode;
    sbp->f_fsid   = (long)ump->um_dev;

    /* Reno's tail.  A byte loop and not uio_copy: 64 bytes, once per statfs
     * call, against a helper this translation unit does not otherwise import.
     * The guard is upstream's -- copying a buffer onto itself is what it
     * avoids, and mp->mnt_stat IS the destination on the mount path. */
    if (sbp != &mp->mnt_stat) {
        for (i = 0; i < MNAMELEN; i++) {
            sbp->f_mntonname[i]   = mp->mnt_stat.f_mntonname[i];
            sbp->f_mntfromname[i] = mp->mnt_stat.f_mntfromname[i];
        }
    }
    return (0);
}


/* ufs_unmount -- detach it again.
 *
 * vflush IS HERE NOW, AND ITS ABSENCE HAD A STATED REASON THAT EXPIRED.  This
 * header said "vflush (1.11 -- no vnode has been produced from this mount
 * until iget exists)" and that was true right up to UFS 1.8b-3a: nothing could
 * reach a mounted filesystem BY NAME, so nothing held one of its vnodes.  A
 * path crosses now, and unmounting without the flush leaves live vnodes whose
 * v_mount points at a table slot the NEXT mount is about to claim -- the stale
 * cover one level down, and harder to see because no walk fails at the moment
 * it is created.
 *
 * IT IS THE FILESYSTEM'S CALL AND NOT THE VFS'S, which is where Reno puts it:
 * `if (error = vflush(mp, NULLVP, flags)) return (error);' is ufs_unmount's
 * own first line.  vfs_dounmount could have called it for free, both being in
 * vfs.mod -- and that would make flush policy the VFS's for every filesystem.
 * THE MOUNT MUST BE OUT OF SERVICE BEFORE THIS RUNS, AND THAT IS A CONTRACT ON
 * EVERY CALLER OF THE VECTOR.  vflush asserts MNT_MPBUSY -- Reno's own
 * assertion, `vendor/4.3BSD-Reno/kern/vfs_subr.c:537', against Reno's own
 * publisher `vfs_busy' at :102.  This header used to say "vflush asserts
 * MNT_MPBUSY and vfs_dounmount publishes it" and stop there, which is true of
 * unmount(2) and reads as though the precondition looks after itself.  It does
 * not.  FOUR probes drive this vector DIRECTLY, on a `struct mount' of their
 * own, because they predate mount(2) and exist to exercise ufs_vfsops in
 * isolation -- ufs_wprobe, ufs_vnprobe, ufs_devprobe and vnops_probe -- and
 * every one of them PANICked here the moment the vflush below landed.  They
 * publish the flag themselves now (apple/fgx#272).  A full day and a green
 * gate passed before anything noticed, because none of those gates is in
 * GATE_TESTS.
 *
 * WHAT RENO DOES THAT THIS STILL DOES NOT, each waiting on a deliverable
 * rather than dropped: mntflushbuf and mntinvalbuf (1.12 -- there are no
 * dirty buffers until something writes), and (formerly vflush -- 1.11, no vnode had been
 * produced from this mount until iget exists), and VOP_CLOSE on the device
 * (1.13, with the real /dev).
 *
 * What is left is the part that is true today: drop the device reference and
 * unhook the private data, so a second mount cannot find a stale one.
 */
int
ufs_unmount(mp, forcibly)
struct mount *mp;
int           forcibly;
{
    struct ufsmount *ump;
    int              error;

    /* Reno refuses MNT_FORCE outright at the top of its unmount and then tests
     * for it again below; the first test wins and the second is dead.  Refused
     * here for a reason that will outlast that oddity: forcing an unmount means
     * revoking vnodes other processes hold, and there is nothing to revoke
     * until 1.11 and no way to revoke it until 1.13. */
    if (forcibly)
        return (EINVAL);

    ump = VFSTOUFS(mp);
    if (ump == 0)
        return (EINVAL);

    /* EVERY VNODE THIS MOUNT PRODUCED GOES, OR THE UNMOUNT DOES NOT.  Reno's
     * first line, and the busy answer is the whole point: a vnode somebody
     * still holds cannot be taken away without the revoke machinery 1.13
     * brings, so the mount stays. */
    error = vflush(mp, (struct vnode *)0, 0);
    if (error)
        return (error);

    /* MARK IT CLEAN ON THE WAY OUT, 2.11BSD update #456's block in ufs_umount:
     *
     *      if ((mp->m_flags & MNT_RDONLY) == 0) {
     *              fs = &mp->m_filsys;
     *              if (fs->fs_flags & MNT_WASCLEAN) {
     *                      fs->fs_fmod = 1;
     *                      fs->fs_flags |= MNT_CLEAN;
     *              }
     *      }
     *      ufs_sync(mp);
     *
     * ONLY IF IT WAS CLEAN WHEN WE MOUNTED IT, and that condition is the one
     * that makes the flag mean anything: a volume brought up dirty has never
     * been checked, and unmounting it does not check it.  Only fsck may say a
     * dirty filesystem is clean.
     *
     * A READ-ONLY MOUNT WRITES NOTHING, and needs to: its on-disk flag was
     * never cleared, so it is already whatever it was. */
    if ((mp->mnt_flag & MNT_RDONLY) == 0 &&
        (mp->mnt_flag & MNT_WASCLEAN) != 0) {
        ump->um_sb.sb_flags |= MNT_CLEAN;
        ump->um_sb.sb_fmod   = 1;
    }
    if (ump->um_sb.sb_fmod)
        (void)ufs_sbupdate(ump->um_devvp, &ump->um_sb);

    /* The device stops carrying a mount, Reno's ufs_umount:357.  It is cleared
     * AFTER the superblock write above, which still needs the device, and
     * before the reference goes. */
    ump->um_devvp->v_specflags &= ~SI_MOUNTEDON;

    vrele(ump->um_devvp);
    mp->mnt_data = (char *)0;
    mp->mnt_op   = (struct vfsops *)0;
    /* AND THE POOL SLOT GOES BACK, which it did not before.  `um_mountp' is
     * how ufs_mount finds a free ufsmount -- the loop at the top of it tests
     * exactly this field -- and nothing here cleared it, so every successful
     * unmount burned one of VFS_NMOUNT permanently.  It has never mattered
     * because nothing could call this: unmount(2) is 1.8b-3c, and the same
     * increment that makes the leak reachable closes it. */
    ump->um_mountp = (struct mount *)0;
    return (0);
}


/* ufs_root -- the root vnode.  1.11a filled this in; 1.8a left it ENOSYS
 * because it calls iget and iget did not exist.
 *
 * THE ROOT IS JUST INODE 2, and that is the whole of it: 2.11BSD fixes the root
 * inode number by convention (inode 0 does not exist and inode 1 is the
 * historical bad-block hack), so there is no lookup to do.  What made this the
 * hinge between two deliverables is that iget needs the mount to know which
 * device and which superblock -- so mount had to come first, and the root vnode
 * had to wait for the inode.
 *
 * IT COMES BACK LOCKED, which is VFS_ROOT's contract in Reno ("returns the
 * locked root vnode") and is here a consequence rather than a decision: iget
 * returns a locked inode and this is one line of it.  Callers that want to
 * HOLD the root -- as a cwd, as rootdir -- must VOP_UNLOCK it first, because
 * namei locks every directory it descends into and the first of those is the
 * one it was given.  Callers that are done with it use iput. */
int
ufs_root(mp, vpp)
struct mount  *mp;
struct vnode **vpp;
{
    struct inode *ip;
    int           error;

    *vpp = (struct vnode *)0;
    error = iget(mp, (ino_t)UFS_ROOTINO, &ip);
    if (error)
        return (error);
    *vpp = ITOV(ip);
    return (0);
}


/*============================================================================
 * THE MOUNT POOL.  UFS 1.8b-1.
 *
 * RENO MALLOCS ITS ufsmount INSIDE mountfs AND THIS CANNOT.  `ufs_mountfs's
 * own header says why -- kernel C has no allocator, by design, so every arena
 * in the VFS is carved by assembly at module load and handed down.  What that
 * costs here is that the storage is claimed whether or not anything mounts,
 * and what it buys is that a mount cannot fail for want of heap at the moment
 * it is asked to succeed.
 *
 * VFS_NMOUNT SLOTS, WHICH IS THE SYSTEM'S MOUNT CEILING AND NOT A UFS ONE.
 * Sizing this smaller would mean a mount(2) that refuses while the mount table
 * still has room, and the caller would have no way to tell the two apart.  At
 * roughly 444 bytes each -- the decoded superblock is almost all of it, with
 * sb_free[50] and sb_inode[100] between them accounting for 400 -- the pool is
 * about 6.2 KB of heap.  That is the largest single allocation this module
 * makes and it is worth knowing before it grows.
 *
 * A SLOT IS FREE WHEN um_mountp IS NULL, so there is no separate bitmap to
 * keep in step with the array.  ufs_mountfs sets it; ufs_unmount clears it.
 *============================================================================
 */
static struct ufsmount ufs_mpool[VFS_NMOUNT];

/* ufs_mountpool -- mark every slot free.  Called from ufs_init, which is the
 * vfsops `once at module load' slot and already runs there.
 *
 * IT IS A STATIC ARRAY AND NOT A HEAP ARENA, which is the opposite of what the
 * rest of the VFS does, so here is the trade.  An arena would be a Kmalloc in
 * mod_init handed down as a pointer -- the shape `_Vfs_BufInit' uses -- and it
 * would cost a published `sizeof(struct ufsmount)' in include/vfs_equ.s plus
 * the runtime assertion in vfslayout.c that keeps such a constant honest,
 * because the assembly has to know how many bytes to ask for.  The array costs
 * ufs.mod 6.2 KB of image against 28,667 free and needs neither.  Revisit if
 * the module tightens: the arena is the better shape, it is just not worth its
 * plumbing for one allocation whose size never varies.
 *
 * ZEROING IS NOT DEFENSIVE, IT IS REQUIRED.  A module bank zero-fills nothing
 * -- apple/fgx#219 was exactly that, a `mount' static holding whatever the
 * far-bank image carried at its address, and `mnt_flag |= MNT_RDONLY' ORing
 * into it preserved a stale MNT_NODEV bit that made spec_open refuse every
 * node under /dev.  A slot is free when um_mountp is null, so this loop is
 * what makes that test mean anything on the first mount. */
static void
ufs_mountpool()
{
    int i;

    for (i = 0; i < VFS_NMOUNT; i++)
        ufs_mpool[i].um_mountp = (struct mount *)0;
}


/* getmdev -- the device path to a block-device vnode.  Reno's getmdev,
 * 4.3BSD-Reno ufs/ufs_vfsops.c.
 *
 *      ndp->ni_nameiop = LOOKUP | FOLLOW;
 *      ndp->ni_segflg = UIO_USERSPACE;
 *      ndp->ni_dirp = fname;
 *      if (error = namei(ndp)) return (error);
 *      vp = ndp->ni_vp;
 *      if (vp->v_type != VBLK) { vrele(vp); return (ENOTBLK); }
 *      if (major(vp->v_rdev) >= nblkdev) { vrele(vp); return (ENXIO); }
 *
 * nblkdev IS NBLKDEV, a constant in fsparam.h: the switch it counts is in
 * vfs.mod, and module C cannot read another bank's variable.
 *
 * ENOTBLK IS THE INTERESTING RETURN and it is upstream's.  Mounting a
 * character device, or a regular file, is the mistake this catches -- and it
 * has to be caught HERE rather than in mountfs, because mountfs goes straight
 * to bread and a character device would answer that from the wrong layer
 * entirely.
 *
 * THE NAMEIDATA IS THE CALLER'S, as it is in Reno, because namei needs one and
 * this has no business owning it: the caller is inside a syscall that already
 * has a per-process nameidata to lend.
 */
int
getmdev(devvpp, fname, ndp)
struct vnode    **devvpp;
char             *fname;
struct nameidata *ndp;
{
    struct vnode *vp;
    int           error;

    ndp->ni_nameiop = LOOKUP | FOLLOW;
    ndp->ni_segflg  = UIO_SYSSPACE;
    ndp->ni_dirp    = fname;
    error = namei(ndp);
    if (error)
        return (error);
    vp = ndp->ni_vp;
    if (vp->v_type != VBLK) {
        vrele(vp);
        return (ENOTBLK);
    }
    if (major(vp->v_rdev) >= NBLKDEV) {
        vrele(vp);
        return (ENXIO);
    }
    *devvpp = vp;
    return (0);
}


/* ufs_mount -- the vfsops entry.  Reno's ufs_mount, 4.3BSD-Reno
 * ufs/ufs_vfsops.c, less three arms it has no work for.
 *
 * THE EXPORT ARM IS GONE because there is no NFS to export to.  Past the
 * MNT_UPDATE arm below, what is left is Reno's own non-update path, which is
 * two calls:
 *
 *      if ((error = getmdev(&devvp, args.fspec, ndp)) != 0) return (error);
 *      error = mountfs(devvp, mp);
 *
 * `data' IS THE DEVICE PATH, WHERE RENO'S IS A `struct ufs_args' TO COPY IN.
 * Upstream needs the indirection because its args carry export flags and an
 * export root alongside `fspec'; with those two arms gone the structure has
 * one live field, and a struct with one field is a copyin that reads a
 * pointer out of a wrapper the caller had to build first.  Stated here rather
 * than left as a silent narrowing -- if an export flag or a remount ever
 * arrives, this argument goes back to being a structure.
 *
 * THE POOL SLOT IS TAKEN BEFORE THE DEVICE IS RESOLVED, so a failure to find
 * one costs no namei and leaves no vnode reference to unwind.  Reno has the
 * same ordering for the same reason, with malloc where this has a scan.
 */
int
ufs_mount(mp, path, data, ndp)
struct mount     *mp;
char             *path;
char             *data;
struct nameidata *ndp;
{
    struct vnode    *devvp;
    struct ufsmount *ump;
    int              i;
    int              error;

    /* THE UPDATE ARM.  Reno's ufs_mount splits on MNT_UPDATE and so does
     * 2.11BSD's; what they do in it is nearly the same and the differences are
     * where each tree keeps the read-only truth:
     *
     *      if (fs->fs_ronly && (mp->mnt_flag & MNT_RDONLY) == 0)
     *              fs->fs_ronly = 0;            -- Reno, ufs/ufs_vfsops.c
     *
     *      if (fs->fs_ronly && ((uap->flags & MNT_RDONLY) == 0)) {
     *              fs->fs_ronly = 0;
     *              mp->m_flags &= ~MNT_RDONLY;  -- 2.11BSD, sys/ufs_mount.c:94
     *      }
     *
     * Reno's second line is missing because its mount(2) already wrote the
     * mount flag before calling in; vfs_mountat does the same, so Reno's form
     * is the one that fits.  THE DIRECTION IS ONE-WAY and vfs_mountat is where
     * that is refused, which is also where both trees put it.
     *
     * sb_ronly IS THE HALF THAT MATTERS HERE.  It is the ON-DISK flag, and it
     * is what iupdat consults (ufs_inode.c) -- so a root that came up
     * read-only stays unwritable until this line clears it, whatever the mount
     * flag says.  That is the whole of `mount -u -w /'.
     *
     * A NULL `data' IS NOT AN ERROR ON THIS ARM, where it is on the other.
     * Upstream spells the same thing as `if (args.fspec == 0) return (0)': a
     * remount need not re-name the device, because the mount already knows it.
     * Verifying a device that WAS named is Reno's next three lines and is not
     * ported -- getmdev would have to walk a path this arm has no need to walk
     * to answer a question the caller cannot get wrong, since the vnode it
     * named is this mount's own root. */
    if (mp->mnt_flag & MNT_UPDATE) {
        ump = VFSTOUFS(mp);
        if (ump == (struct ufsmount *)0)
            return (EINVAL);
        if (ump->um_sb.sb_ronly && (mp->mnt_flag & MNT_RDONLY) == 0) {
            ump->um_sb.sb_ronly = 0;
            /* AND THE VOLUME IS DIRTY FROM THIS MOMENT, which has to be said
             * ON THE PLATTER before anything uses the writable mount.
             *
             * MEASURED, and it is the worst shape a filesystem bug takes --
             * SILENT, and compounding.  ufs_mountfs clears MNT_CLEAN in core
             * and syncs, but a READ-ONLY mount has nothing to sync, so a root
             * that came up read-only keeps the on-disk clean flag.  This
             * transition is what makes it writable, and without clearing the
             * flag here the machine ran, wrote, and rebooted, and the NEXT
             * boot read `file system is clean; not checking' and skipped the
             * check on a volume nobody had checked.  Two cycles of that and
             * fsck finds SIZE=0 FILE HAS ALLOCATED BLOCKS and PARTIALLY
             * ALLOCATED INODE -- damage that accumulated behind a flag that
             * said there was nothing to look at.
             *
             * UPSTREAM'S UPDATE ARM DOES NOT DO THIS (2.11BSD ufs_mount.c:94
             * is `fs->fs_ronly = 0; mp->m_flags &= ~MNT_RDONLY;' and no more),
             * and it does not have to: its fs_flags in core already lost
             * MNT_CLEAN at mountfs, and its update(8) syncs every 30 seconds,
             * so the first allocation sets fs_fmod and the flag reaches the
             * disk soon after.  That is a RACE upstream wins by having a
             * busier machine; the window is real in both, and closing it costs
             * one superblock write at the one moment the answer changes.
             *
             * fs_fmod is set the way Reno's mountfs sets it for a writable
             * mount (`if (ronly == 0) fs->fs_fmod = 1'), so the write also
             * refreshes the volume's date. */
            ump->um_sb.sb_flags &= ~MNT_CLEAN;
            ump->um_sb.sb_fmod   = 1;
            (void)ufs_sbupdate(ump->um_devvp, &ump->um_sb);
        }
        return (0);
    }

    if (data == (char *)0)
        return (EINVAL);        /* no device named: nothing to mount */

    ump = (struct ufsmount *)0;
    for (i = 0; i < VFS_NMOUNT; i++) {
        if (ufs_mpool[i].um_mountp == (struct mount *)0) {
            ump = &ufs_mpool[i];
            break;
        }
    }
    if (ump == (struct ufsmount *)0)
        return (EMFILE);        /* every ufsmount slot is in use */

    error = getmdev(&devvp, data, ndp);
    if (error)
        return (error);

    /* ALREADY MOUNTED?  This is 2.11BSD's FIRST scan, and it is a second pass
     * here rather than one loop because the two scans want different things at
     * different times: the free slot is wanted BEFORE the namei (above, for
     * the reason stated there), and the device number does not exist until
     * getmdev has resolved it.
     *
     * usr/sys/sys/ufs_mount.c:mountfs() is the authority, and it is 2.11BSD's
     * rather than Reno's because 2.11BSD is the tree with a FIXED POOL, as
     * this is; Reno mallocs a mount per filesystem and asks the question
     * elsewhere:
     *
     *      for (mp = &mount[0]; mp < &mount[NMOUNT]; mp++)
     *              if (mp->m_inodp != 0 && dev == mp->m_dev) {
     *                      ...
     *                      error = EBUSY;
     *
     * WHAT IT PREVENTS IS NOT A DUPLICATE MOUNT, IT IS TWO SUPERBLOCKS.  Each
     * mount decodes the volume's superblock into its own `um_sb', and while
     * every mount is read-only that is merely wasteful.  At 1.12 both copies
     * carry a free list and inode counters and both write back, over one
     * device.  apple/fgx#269. */
    for (i = 0; i < VFS_NMOUNT; i++) {
        if (ufs_mpool[i].um_mountp != (struct mount *)0 &&
            ufs_mpool[i].um_dev == devvp->v_rdev) {
            vrele(devvp);       /* getmdev's reference */
            return (EBUSY);
        }
    }

    error = ufs_mountfs(devvp, mp, ump);
    if (error) {
        /* THE SLOT GOES BACK TOO, and it did not before.  ufs_mountfs sets
         * `ump->um_mountp' before its own last call, so a failure after that
         * point left the pool one slot smaller with nothing saying so.  It
         * cannot happen today -- ufs_statfs has no failing arm -- and the line
         * costs nothing to be right in advance of one.  apple/fgx#269. */
        ump->um_mountp = (struct mount *)0;
        vrele(devvp);           /* getmdev's reference; mountfs took none */
        return (error);
    }

    /* THE MOUNT POINT, which is what Reno's ufs_mount does here too:
     *
     *      (void) copyinstr(path, fs->fs_fsmnt, sizeof(fs->fs_fsmnt)-1, &size);
     *      bcopy(fs->fs_fsmnt, mp->mnt_stat.f_mntonname, MNAMELEN);
     *
     * (ufs/ufs_vfsops.c:182-185).  Upstream stages through the superblock's
     * fs_fsmnt so the volume remembers where it was last mounted; ufs_sb.c
     * decodes no such field, so the copy is direct and the on-disk memory is
     * the divergence.  No copyinstr either -- `path' is already a kernel
     * pointer here, vfs_mountat having staged it (a syscall's own buffer). */
    for (i = 0; i < MNAMELEN - 1 && path[i]; i++)
        mp->mnt_stat.f_mntonname[i] = path[i];
    return (0);
}


/* ufs_init -- once, at module load.  1.11a gave it something to do: the inode
 * hash's chains have to point at themselves before anything walks one, and an
 * all-zero table is not an empty circular list, it is sixteen null pointers
 * that the first walk follows.
 *
 * AND mount(2) CANNOT FIND UFS UNTIL THE LAST LINE HAS RUN.  Reno's vfssw[]
 * names `&ufs_vfsops' in its initialiser (kern/vfs_conf.c); this one lives in
 * vfs.mod, which cannot name an address inside this module, so the row is
 * handed over from here.  Last, so a mount(2) never finds a filesystem whose
 * hash and pool are not ready. */
int
ufs_init()
{
    ufs_ihashinit();
    ufs_mountpool();        /* 1.8b-1 -- see the note above on why it zeroes */
    return (vfs_setvfsops(MOUNT_UFS, &ufs_vfsops));
}


/* ufs_sync -- write back what the write path deferred.  4.3BSD-Reno
 * ufs/ufs_vfsops.c:526.  UFS 2.6, apple/fgx#332.
 *
 * THE SUPERBLOCK IS THE WHOLE OF IT HERE, and the reason the other half of
 * upstream's function is absent is worth stating rather than leaving as a
 * silence.  Reno's ufs_sync does two things: write the superblock when
 * `fs_fmod' is set, then walk `mp->mnt_mounth' -- the mount's list of its own
 * vnodes -- calling iupdat and vflushbuf on each dirty one.  This tree keeps
 * no such per-mount vnode list, and its write path updates an inode inside
 * ufs_inactive and ufs_write rather than deferring it; the buffer cache's
 * dirty blocks reach the platter through bwrite/bdwrite on their own path.
 * What was left with no writer at all is the superblock, which is exactly the
 * defect #332 measures.
 *
 * WHY IT MATTERS THAT IT IS THE SUPERBLOCK.  ufs_alloc hands out blocks from a
 * batch of up to fifty read into `sb_free[]', writing the block back to disk
 * only when the batch empties -- upstream's policy, and correct, because the
 * on-disk free-list HEAD must not lag the blocks already given away.  It sets
 * `sb_fmod' for everything in between and trusts sync(2) to notice.  With
 * nothing noticing, an allocated block stayed on the on-disk free list and the
 * next mount gave it away again: measured as `block 17159 is claimed by BOTH
 * inode 567 and inode 568'.
 *
 * `waitfor' REACHES THE INODES AND NOT THE SUPERBLOCK.  iupdat takes it and
 * uses it; ufs_sbupdate is unconditionally synchronous and its own header says
 * why, so the superblock half has nothing for the argument to select.
 *
 * fs_fmod IS CLEARED BEFORE THE WRITE, not after, which is ufs_alloc's line
 * for its reason: the flag means "the in-core copy is ahead of the disk", and
 * that stops being true at the moment the encode reads it.
 *
 * UPSTREAM'S LAST LINE IS NOT HERE, and where it went is apple/fgx#398:
 *
 *      vflushbuf(ump->um_devvp, waitfor == MNT_WAIT ? B_SYNC : 0);
 *
 * Reno reaches a device node's delayed writes in TWO places -- the mnt_mounth
 * walk vflushbufs every dirty vnode of the mount (ufs/ufs_vfsops.c:571), and
 * then the mount's own device vnode (:580).  The FIRST is what covers a write
 * made through /dev/sd<n>, whose buffer hangs off the vnode the WRITER opened
 * rather than off um_devvp; those are aliases, not one vnode.  This tree keeps
 * no mnt_mounth to walk, so the second line alone would find nothing.
 *
 * AND PER-MOUNT IS THE WRONG SCOPE HERE ANYWAY, which is a measurement rather
 * than a preference: a mounted filesystem's block device cannot be opened at
 * all (spec_open's VBLK arm answers EBUSY through mountedon), so the only
 * writer that could dirty a buffer on a MOUNTED device is this filesystem, and
 * every write it makes is a bwrite already.  A flush reached through the mount
 * list can therefore never have anything to do.  The delayed writes that do
 * exist are on UNMOUNTED spindles, which no mount-list walk visits, so the
 * flush belongs to sync(2) itself: vfs_syscalls.c's vfs_sync, one call,
 * bflush(NODEV).
 */
int
ufs_sync(mp, waitfor)
struct mount *mp;
int           waitfor;
{
    struct ufsmount *ump;
    int              error;
    int              allerror;

    ump = VFSTOUFS(mp);
    if (ump == (struct ufsmount *)0)
        return (EINVAL);
    /* THE INODES FIRST, and they are not optional: every operation that
     * changes an inode without changing its size marks it ICHG and leaves the
     * write to ufs_inactive, which only runs when the last reference goes.  An
     * inode that stays referenced -- a process's working directory -- never
     * reached the platter, so `mkdir d; rmdir d' left the parent's link count
     * wrong on disk.  ufs_iflushall's header carries the measurement. */
    allerror = ufs_iflushall(waitfor);

    /* THE SHUTDOWN SYNC MARKS THE VOLUME CLEAN, which is 2.11BSD update #456's
     * fsclean() (usr/sys/sys/ufs_subr.c) doing its per-mount half here because
     * the superblock is this module's and the mount-list walk is the far
     * bank's.  vfs_sync() sets MNT_CLEANSYNC for the duration of this one call.
     *
     *      if (fs->fs_flags & MNT_WASCLEAN) {
     *              fs->fs_flags |= MNT_CLEAN;
     *              fs->fs_fmod = 1;
     *              ufs_sync(mp);
     *              fs->fs_flags &= ~MNT_CLEAN;
     *      }
     *
     * ONLY IF IT WAS CLEAN AT MOUNT -- the rule ufs_unmount follows and the
     * one that keeps the flag meaning something: a volume brought up dirty has
     * never been checked, and going down tidily does not check it.
     *
     * fs_fmod IS FORCED so the write happens even on a volume nothing dirtied;
     * without that a machine that booted and rebooted without allocating
     * anything would leave the flag exactly as it found it, which is to say
     * dirty.
     *
     * AND MNT_CLEAN IS CLEARED AGAIN AFTERWARDS, upstream's own last line: the
     * call does not have to be the last thing the machine does, and one that
     * keeps running must not be left claiming to be clean. */
    if ((mp->mnt_flag & MNT_CLEANSYNC) &&
        (ump->um_sb.sb_flags & MNT_WASCLEAN)) {
        ump->um_sb.sb_flags |= MNT_CLEAN;
        ump->um_sb.sb_fmod   = 1;
    }

    if (ump->um_sb.sb_fmod) {
        ump->um_sb.sb_fmod = 0;
        error = ufs_sbupdate(ump->um_devvp, &ump->um_sb);
        ump->um_sb.sb_flags &= ~MNT_CLEAN;
        if (allerror == 0)
            allerror = error;
    }

    return (allerror);
}


/* THE VECTOR.  Order is vfsops.h's, which is Reno's for the six slots kept.
 *
 * A FUNCTION-POINTER TABLE IN A MODULE WORKS BECAUSE OF THE LOAD-TIME
 * RELOCATION PASS -- fcc emits these as long pointers and the loader resolves
 * their banks, the same mechanism dead_vnops and spec_vnops already rely on in
 * vfs.mod.  It is not something this file has to arrange, but it is worth
 * knowing it is happening. */
struct vfsops ufs_vfsops = {
    ufs_mount,
    ufs_unmount,
    ufs_root,
    ufs_statfs,
    ufs_sync,
    ufs_init
};

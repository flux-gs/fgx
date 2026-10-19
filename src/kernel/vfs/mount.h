/* mount.h -- struct mount and struct statfs, from 4.3BSD-Reno, sized.
 *
 * Reno's f_spare[9] is dropped (36 bytes of nothing) and the two mount-point
 * names are MNAMELEN rather than 90.  Field order and names are Reno's, so
 * ported vfs code reads against a familiar structure.
 *
 * Pinned by toolchain/tests/M37/vfslayout.c, which includes this header.
 */
#ifndef _MOUNT_H_
#define _MOUNT_H_

#include "fsparam.h"

struct statfs {
    short   f_type;
    short   f_flags;
    long    f_fsize;                /* fundamental fs block size */
    long    f_bsize;                /* optimal transfer block size */
    long    f_blocks;               /* total data blocks */
    long    f_bfree;                /* free blocks */
    long    f_bavail;               /* free blocks available to non-root */
    long    f_files;                /* total file nodes */
    long    f_ffree;                /* free file nodes */
    long    f_fsid;                 /* filesystem id (Reno: fsid_t, 2 longs) */
    char    f_mntonname[MNAMELEN];
    char    f_mntfromname[MNAMELEN];
};

struct mount {
    struct mount   *mnt_next;
    struct mount   *mnt_prev;
    struct vfsops  *mnt_op;
    struct vnode   *mnt_vnodecovered;
    struct vnode   *mnt_mounth;
    /* LONG, not int.  This was narrowed to 16 bits when the structure was
     * sized, which looked free because every flag anyone had looked at --
     * MNT_RDONLY and friends -- lives in the low byte.  It is not free: Reno
     * puts the KERNEL-STATE flags in bits 20 through 24 (MNT_MLOCK, MNT_MWAIT,
     * MNT_MPBUSY, MNT_MPWANT, MNT_UNMOUNT), so a 16-bit field cannot represent
     * "a scan of this mount point is in progress" at all.  Every test of one
     * would have read zero and every set would have been discarded, silently.
     * Two bytes per mount, and there are a handful of mounts. */
    long            mnt_flag;
    uid_t           mnt_exroot;
    struct statfs   mnt_stat;
    char           *mnt_data;       /* private data (Reno: qaddr_t) */
};

/* mnt_flag bits, Reno's values.  The low byte is the user-visible mount
 * options, reported through statfs; the high bits are internal state.  Only
 * the ones this port uses are listed -- a second copy of a number drifts --
 * but they keep Reno's numbering so a flag word means the same thing in both. */
/* What statfs(2) reports.  Reno's own mask (sys/mount.h), and it was spelled
 * as a bare 0xFF at both use sites before statfs(2) added a third. */
#define MNT_VISFLAGMASK 0x000000ffL /* flags visible through statfs */

#define MNT_RDONLY      0x00000001L /* read only filesystem */
/* MNT_NOEXEC refuses every exec of a file on the volume, which ld_exec_check
 * asks before Load_Binary reads a byte -- Reno's exec tests it first of all,
 * ahead of the mode and ahead of the credential (kern/kern_exec.c:119). */
#define MNT_NOEXEC      0x00000004L /* can't exec from filesystem */
/* MNT_NOSUID allows the exec and declines only the privilege: vn_execsugid
 * answers "no change" for every file on the volume, so a set-id binary there
 * runs as its caller (Reno kern/kern_exec.c:123). */
#define MNT_NOSUID      0x00000008L /* don't honor setuid bits on fs */
/* MNT_NODEV is the one user-visible flag with teeth: a filesystem mounted with
 * it does not get to name devices, so a removable volume carrying its own
 * /dev/mem cannot hand out access to memory.  spec_open enforces it, which is
 * the right place -- the node is harmless until somebody opens it. */
#define MNT_NODEV       0x00000010L /* do not interpret special files */
/* MNT_UPDATE is a CONTROL flag, not a property: it says this mount(2) is a
 * remount of a mount that already exists, and it never survives the call --
 * vfs_mountat sets it on the live mount so ufs_mount can see which arm it is
 * in, and clears it before returning, exactly as Reno does.  It is above the
 * statfs mask for that reason, and carries userland's number (sys/mount.h). */
#define MNT_UPDATE      0x00001000L /* not a real mount, an update */
/* THE CLEAN PAIR, 2.11BSD update #456 ("filesystem clean", Johnny Billquist).
 * MNT_CLEAN is ON DISK, in the superblock's fs_flags: the volume was unmounted
 * cleanly, so fsck may skip it.  MNT_WASCLEAN is IN CORE: it was clean when
 * this mount read it.  The pair is what makes a boot fsck affordable -- a full
 * check of a 32000-block root reads the whole i-list and every block of every
 * file, which measured at over 45 seconds through the single-block read path.
 *
 * They live above MNT_VISFLAGMASK on purpose: statfs(2) must not report them,
 * being state of the volume rather than options of the mount. */
#define MNT_CLEAN       0x00002000L /* file system is clean (on disk) */
#define MNT_WASCLEAN    0x00004000L /* it was clean at mount (in core) */
/* MNT_CLEANSYNC is a CONTROL bit like MNT_UPDATE, and it never survives the
 * call: vfs_sync() sets it on each mount for the duration of one VFS_SYNC so
 * the filesystem knows this sync is the LAST one -- the machine is going down
 * and the volume should be left marked clean.  It is the channel upstream does
 * not need, its fsclean() reaching the superblock directly where here the
 * mount-list walk and the superblock live in different banks. */
#define MNT_CLEANSYNC   0x00008000L /* this sync is the shutdown one */
#define MNT_MLOCK       0x00100000L /* locked so the subtree is stable */
#define MNT_MWAIT       0x00200000L /* someone is waiting for the lock */
#define MNT_MPBUSY      0x00400000L /* a scan of the mount point is running */
#define MNT_MPWANT      0x00800000L /* waiting for the mount point */
#define MNT_UNMOUNT     0x01000000L /* unmount in progress */

/* getfsstat(2)'s and VFS_SYNC's waitfor.  The SAME two values userland's
 * <sys/mount.h> carries -- they cross the seam in getfsstat's flags argument,
 * so a second numbering here would be a wire mismatch nothing checks. */
#define MNT_WAIT        1
#define MNT_NOWAIT      2

#endif /* _MOUNT_H_ */

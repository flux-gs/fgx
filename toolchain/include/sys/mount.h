/* FGX libc -- sys/mount.h.  struct statfs, statfs(2), getfsstat(2).
 *
 * THIS IS THE USERLAND HALF OF A STRUCT THE KERNEL ALSO DECLARES.  The kernel
 * copy is src/kernel/vfs/mount.h -- 4.3BSD-Reno's field order and names, sized
 * for this machine -- and the two are compared field for field by
 * tools/check_statfs_layout.py, which the build runs.  Do not edit one alone.
 *
 * A wire format, not a convenience: SYS_STATFS and SYS_GETFSSTAT copy these
 * bytes out of the kernel and userland reads them directly, so a member added,
 * widened or reordered on one side and not the other shifts every member after
 * it.  That is not a crash; it is df(1) reporting the wrong free space.  The
 * previous version of this file was 58 bytes against the kernel's 100 and had
 * no inode counts at all -- it described a ProDOS volume table that no longer
 * exists.
 *
 *----------------------------------------------------------------------------
 * THE NAME `f_bsize' MEANS DIFFERENT THINGS IN THE TWO BSDs, AND WE FOLLOW
 * RENO.  2.11BSD's statfs (usr/sys/h/mount.h) is
 *
 *      short f_bsize;      // fundamental file system block size
 *      short f_iosize;     // optimal transfer block size
 *
 * and Reno's (sys/mount.h) is
 *
 *      long  f_fsize;      // fundamental file system block size
 *      long  f_bsize;      // optimal transfer block size
 *
 * -- so `f_bsize' is the FUNDAMENTAL size to a 2.11BSD program and the OPTIMAL
 * one to a Reno program.  df(1) is ported from 2.11BSD and reads f_bsize
 * meaning "fundamental"; it gets the right answer here only because
 * ufs_statfs() sets f_fsize and f_bsize to the same FS_BLKSIZE.  Should a
 * filesystem ever set them apart, that is where it breaks, and it will not
 * announce itself.
 */
#ifndef _SYS_MOUNT_H
#define _SYS_MOUNT_H

#define MNAMELEN 32                    /* kernel fsparam.h; Reno's is 90     */

struct statfs {
    short f_type;                      /* filesystem type (MOUNT_UFS)        */
    short f_flags;                     /* copy of mount flags, MNT_VISFLAGMASK */
    long  f_fsize;                     /* fundamental filesystem block size  */
    long  f_bsize;                     /* optimal transfer block size        */
    long  f_blocks;                    /* total data blocks                  */
    long  f_bfree;                     /* free blocks                        */
    long  f_bavail;                    /* free blocks available to non-root  */
    long  f_files;                     /* total file nodes                   */
    long  f_ffree;                     /* free file nodes                    */
    long  f_fsid;                      /* filesystem id (Reno: fsid_t)       */
    char  f_mntonname[MNAMELEN];       /* directory mounted on               */
    char  f_mntfromname[MNAMELEN];     /* mounted filesystem                 */
};                                     /* 100 bytes -- pinned by the checker */

/* Filesystem types, kernel vfsops.h.  INITMOUNTNAMES is 2.11BSD's own table
 * and mount(8)/umount(8) both index it by f_type to print a name. */
#define MOUNT_NONE      0
#define MOUNT_UFS       1
#define MOUNT_ISOFS     5      /* netbsd-0-9's number and name */
#define MOUNT_PRODOS    10     /* FGX-local; 2-9 are BSD's -- see below */
#define MOUNT_MAXTYPE   10

/* 2-9 ARE NAMED AND NOT NULL because umount(8)'s fsnametotype walks this
 * table until it meets a null, so a hole before `prodos' would make it
 * unreachable by name.  The names are the BSD ones those numbers carry --
 * Reno's nfs and mfs, and netbsd-0-9's msdos (Reno's MOUNT_PC) through afs --
 * and no kernel here answers to any of them: vfssw has no row, so mount(2)
 * says ENODEV. */
#define INITMOUNTNAMES { \
        "none",         /* 0 MOUNT_NONE */ \
        "ufs",          /* 1 MOUNT_UFS */ \
        "nfs",          /* 2 */ \
        "mfs",          /* 3 */ \
        "msdos",        /* 4 */ \
        "isofs",        /* 5 */ \
        "fdesc",        /* 6 */ \
        "kernfs",       /* 7 */ \
        "devfs",        /* 8 */ \
        "afs",          /* 9 */ \
        "prodos",       /* 10 MOUNT_PRODOS */ \
        0,                                \
}

/* Mount flags visible through statfs.  2.11BSD's numbering (usr/sys/h/mount.h),
 * which is Reno's low byte, which is what the kernel's src/kernel/vfs/mount.h
 * carries -- one set of numbers on both sides of the seam and in the tools.
 *
 * MOST OF THESE HAVE NO ENFORCER YET and are here because mount(8) parses them
 * from fstab(5) and from -o: mntopts.h names every one, so a header missing
 * any of them is a port that will not compile.  vfs_mountat keeps the two that
 * mean something (MNT_RDONLY, MNT_NODEV) and drops the rest, which is a
 * silence worth knowing about -- `mount -o noexec' is accepted and ignored. */
#define MNT_RDONLY      0x0001         /* read only filesystem               */
#define MNT_SYNCHRONOUS 0x0002         /* written synchronously -- no writer  */
#define MNT_NOEXEC      0x0004         /* no exec from here -- no enforcer    */
#define MNT_NOSUID      0x0008         /* no setuid -- no credential to check */
#define MNT_NODEV       0x0010         /* do not interpret special files     */
#define MNT_QUOTA       0x0020         /* quotas -- a campaign non-goal      */
#define MNT_ASYNC       0x0040         /* written asynchronously -- no writer */
#define MNT_NOATIME     0x0080         /* do not update access times         */
#define MNT_VISFLAGMASK 0x0fff         /* what statfs reports                */

/* Control flags -- not filesystem properties.  MNT_UPDATE is a remount that
 * vfs_mountat does not implement; it answers EINVAL, which is the errno
 * mount_ufs(8) already prints "specify a filesystem type" for. */
#define MNT_UPDATE      0x1000         /* not a real mount, an update        */
/* 2.11BSD update #456's clean pair.  MNT_CLEAN is the on-disk bit in the
 * superblock's fs_flags; MNT_WASCLEAN says it was clean when the running
 * kernel mounted it.  fsck(8) reads both and skips a clean filesystem unless
 * -f; nothing else in userland has business with them. */
#define MNT_CLEAN       0x2000         /* file system is clean               */
#define MNT_WASCLEAN    0x4000         /* it was clean at mount              */
#define MNT_FORCE       0x2000         /* unmount a busy filesystem          */

/* Flags for getfsstat(2).  Reno refreshes each mount's cached statfs unless
 * MNT_NOWAIT is given; FGX always refreshes, there being no device to wait
 * on -- see the BUGS section of getfsstat(2). */
#define MNT_WAIT        1
#define MNT_NOWAIT      2

/* mount(2) is 4.3BSD-Reno's: a MOUNT_* type, the directory, the flags, and
 * type-specific data -- for MOUNT_UFS, the special file.  umount(2) is
 * 2.11BSD's and takes THE SPECIAL FILE, not the directory. */
int mount(int type, char *dir, int flags, char *data);
int umount(char *spec);

int statfs(char *path, struct statfs *buf);

/* Copy a struct statfs for each mounted filesystem into buf, which is bufsize
 * BYTES (not entries).  Returns the number of mounts written, or -1. */
int getfsstat(struct statfs *buf, int bufsize, int flags);

/* getmntinfo(3): the whole mount table at once, in storage libc owns.  Sets
 * *mntbufp to it and returns the count, or 0 on failure. */
int getmntinfo(struct statfs **mntbufp, int flags);

#endif

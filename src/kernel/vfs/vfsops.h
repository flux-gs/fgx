/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno sys/mount.h
 *   Ported from sys/mount.h, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 */
/* vfsops.h -- the operations a FILESYSTEM TYPE provides.  UFS 1.8a.
 *
 * The vnode ops vector (vnode.h) is per-FILE: read this vnode, look up a name
 * in it.  This one is per-FILESYSTEM: mount this device, tell me your root,
 * report your free space.  Reno separates them and so does this port, because
 * they have different lifetimes -- a vfsops is chosen once at mount time and a
 * vnodeops is consulted on every operation.
 *
 *============================================================================
 * mount(2) FINDS ONE OF THESE IN `vfssw[]', indexed by the MOUNT_* number
 * below, which is Reno's kern/vfs_conf.c.  The table is in vfs.mod
 * (vfs_vnops.c) and each filesystem module hands its own row over from
 * mod_init, because a filesystem here is loaded rather than linked in -- so a
 * row is non-null exactly when that filesystem's module came up.
 *============================================================================
 */
#ifndef _VFSOPS_H_
#define _VFSOPS_H_

#include "fsparam.h"

/* WHAT IS CARRIED AND WHAT IS NOT.  Reno's vfsops has ten slots; four of them
 * describe things FGX has no notion of, and carrying them as null pointers
 * would be ten chances to call one.
 *
 *   vfs_quotactl  quotas are a campaign non-goal (inode.h drops i_dquot too)
 *   vfs_fhtovp    NFS file handles, and there is no NFS
 *   vfs_vptofh    likewise
 *   vfs_start     Reno calls it after mount(2) to let a filesystem finish
 *                 asynchronously; nothing here mounts asynchronously
 *
 * vfs_sync WAS ON THAT LIST AND THE REASON GIVEN FOR IT WAS WRONG.  It read
 * "there is no update(2) daemon and no delayed-write policy to flush; 1.12's
 * write path decides what sync means here" -- and 1.12's write path decided
 * that the superblock is written back only when the free-list batch empties,
 * which is upstream's own policy and IS a delayed write.  With nothing
 * honouring `fs_fmod', up to fifty allocated blocks stayed on the on-disk free
 * list and were handed out a second time after a remount: apple/fgx#332,
 * measured as `block 17159 is claimed by BOTH inode 567 and inode 568'.
 *
 * The six that remain are the ones a mount actually needs.  SLOT ORDER IS
 * RENO'S for the ones kept, so a reader with Reno open sees the same shape --
 * sync sits between statfs and init there too -- but the offsets are NOT
 * Reno's, and nothing may index this by a Reno constant. */
struct vfsops {
    int (*vfs_mount)();     /* mp, path, data, ndp -> errno */
    int (*vfs_unmount)();   /* mp, forcibly   -> errno */
    int (*vfs_root)();      /* mp, vpp        -> errno */
    int (*vfs_statfs)();    /* mp, sbp        -> errno */
    int (*vfs_sync)();      /* mp, waitfor    -> errno */
    int (*vfs_init)();      /* once, at module load */
};

/* Reno spells these as macros so a call site reads as a verb rather than as a
 * pointer chase, and they are kept for the same reason.  A filesystem is
 * reached ONLY through these -- the whole point of the indirection is that the
 * caller does not know which filesystem it has. */
/* ndp IS AN ARGUMENT BECAUSE A MOUNT HAS TO LOOK A DEVICE UP, and that is
 * upstream's shape: `VFS_MOUNT(mp, uap->dir, uap->data, ndp)'
 * (4.3BSD-Reno kern/vfs_syscalls.c).  The filesystem does not own a nameidata
 * -- it is lent one by the syscall that already has a per-process one -- so
 * threading it here is what lets `getmdev' call namei at all.  Added at
 * 1.8b-1, when ufs_mount stopped being ENOSYS and needed to resolve a name. */
#define VFS_MOUNT(mp, path, data, ndp) \
                                   (*(mp)->mnt_op->vfs_mount)(mp, path, data, ndp)
#define VFS_UNMOUNT(mp, forcibly)  (*(mp)->mnt_op->vfs_unmount)(mp, forcibly)
#define VFS_ROOT(mp, vpp)          (*(mp)->mnt_op->vfs_root)(mp, vpp)
#define VFS_STATFS(mp, sbp)        (*(mp)->mnt_op->vfs_statfs)(mp, sbp)
#define VFS_SYNC(mp, waitfor)      (*(mp)->mnt_op->vfs_sync)(mp, waitfor)

/* Filesystem type numbers: mount(2)'s first argument, vfssw[]'s index, and
 * statfs's f_type.  Reno's MOUNT_* values, kept because a `df` that prints a
 * type number should print the same number a PDP-11 would.  MOUNT_MAXTYPE is
 * the highest row vfssw[] has, as in Reno; toolchain/include/sys/mount.h
 * carries the same three for userland. */
#define MOUNT_NONE      0
#define MOUNT_UFS       1
/* 2-9 are BSD's -- Reno's NFS, MFS and PC, netbsd-0-9's ISOFS through AFS --
 * and are left empty here rather than reused, for the reason above. */
#define MOUNT_ISOFS     5       /* netbsd-0-9's: ISO 9660, isofs.mod */
#define MOUNT_PRODOS    10      /* FGX-local: no BSD assigns ProDOS a number */
#define MOUNT_MAXTYPE   10

#endif /* _VFSOPS_H_ */

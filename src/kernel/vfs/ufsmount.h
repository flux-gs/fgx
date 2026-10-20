/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno ufs/ufsmount.h
 *   Ported from ufs/ufsmount.h, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* ufsmount.h -- what UFS hangs off a mount point.  UFS 1.8a.
 *
 * `struct mount` is the VFS's, identical for every filesystem type; this is the
 * part only UFS understands, reached through mnt_data.  The indirection is what
 * lets namei walk across a mount point without knowing what is on the other
 * side.
 *
 * THE SUPERBLOCK IS EMBEDDED, NOT POINTED AT, and that is the one structural
 * difference from Reno.  Reno's um_fs is a `struct fs *` into a buffer it holds
 * for the life of the mount, because there the in-core superblock IS the
 * on-disk bytes and holding the buffer costs nothing.  This port DECODES the
 * superblock (ufs_fs.h explains why: unaligned longs, PDP-11 byte order), so
 * there is nothing to point at -- the decoded form has to live somewhere, and
 * the mount is where it belongs.
 *
 * It also settles a question 1.10a left open.  ufs_sbread's comment said
 * holding the buffer "belongs with ufs_mount at 1.8, when there is a struct
 * mount to hang the copy off".  This is that structure, and the answer turned
 * out to be that the buffer is not held at all: the decode is the copy.
 *
 * Dropped from Reno, all quota state and all campaign non-goals: um_quotas,
 * um_cred, um_btime, um_itime, um_qflags.  inode.h drops i_dquot on the same
 * grounds.
 */
#ifndef _UFSMOUNT_H_
#define _UFSMOUNT_H_

#include "fsparam.h"
#include "ufs_fs.h"

struct ufsmount {
    struct mount   *um_mountp;      /* the VFS structure pointing back here */
    struct vnode   *um_devvp;       /* the block device this came from */
    dev_t           um_dev;         /* ...and its number, for iget's hash */
    struct ufs_sb   um_sb;          /* THE SUPERBLOCK ITSELF -- see above */
};

/* Reno's spelling.  mnt_data is a char * here rather than Reno's qaddr_t, so
 * the cast is doing real work and not decoration. */
#define VFSTOUFS(mp)    ((struct ufsmount *)((mp)->mnt_data))

/* ITOUMP -- an inode's mount, which is where its superblock lives.  UFS 1.12a.
 *
 * `i_fs` is declared `struct fs *` because Reno declares it that way and the
 * decode side had no reason to disagree; iget stores a `struct ufsmount *`
 * through it (ufs_inode.c) and until 1.12a nothing read it back.  The write
 * path does -- the allocator takes the superblock, and iupdat takes sb_ronly
 * -- so the cast gets a name here rather than being spelled at each use.
 *
 * Reno does not need this: there `i_fs` really is the FFS superblock pointer
 * and `ip->i_fs->fs_ronly` is a plain field read.  2.11BSD writes the same
 * expression for the same reason.  The indirection is FGX's, because this port
 * keeps the superblock inside the mount rather than allocating it separately.
 */
#define ITOUMP(ip)      ((struct ufsmount *)((ip)->i_fs))

#endif /* _UFSMOUNT_H_ */

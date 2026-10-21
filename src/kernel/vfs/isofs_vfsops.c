/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: netbsd-0-9 sys/isofs/isofs_vfsops.c;
 *   4.4BSD-Lite2 sys/isofs/cd9660/cd9660_vfsops.c
 *   isofs_mount, iso_mountfs, isofs_unmount, isofs_root, isofs_statfs and
 *   isofs_init, in FGX's VFS terms (prodos_vfsops.c's shape: the mount pool,
 *   getmdev inline, the device path as `data').  FGX deltas: export
 *   requests, mountroot and NFS file handles are not carried, FGX having none
 *   of the three; the logical block size is the volume's own (upstream fixes
 *   2048 and then reads it anyway); and the mount refuses a device that
 *   already carries one, iso_mountedon's question asked of the flag every
 *   filesystem sets.
 *   Original work:
 *   Copyright (c) 1994 The Regents of the University of California.
 *   All rights reserved.
 */
/* isofs_vfsops.c -- mounting an ISO 9660 volume.  Always read-only: a write
 * mount is EROFS, isofs_mount's own first answer, and mount_isofs(8) never
 * asks for one.
 */

#include "fsparam.h"
#include "vnode.h"
#include "specdev.h"
#include "buf.h"
#include "mount.h"
#include "namei.h"
#include "vfsops.h"
#include "isofs.h"

extern int           bread();
extern void          brelse();
extern int           namei();
extern void          vrele();
extern int           vflush();
extern int           vfs_setvfsops();
extern void          kc_panic();
extern void          iso_hashinit();
extern int           iso_iget();
extern void          iso_parse();
extern struct vfsops isofs_vfsops;
int                  isofs_statfs();    /* below; isofs_mount ends in it */

static struct isomount iso_mpool[VFS_NMOUNT];


/* iso_pvd -- find the primary volume descriptor and read what the mount
 * needs from it into `imp': iso_mountfs's walk, from sector 16 to the
 * terminator, every descriptor checked for "CD001" (ISO 9660 8.1, 8.3).  Up
 * to sector 100, upstream's bound, so a volume with no terminator ends.
 *
 * EVERYTHING READ IS IN THE DESCRIPTOR'S FIRST 1 KB -- the root record ends
 * at byte 190 -- so one buffer serves.  `rootdr' receives the root's
 * directory record, ISO_ROOTDR_LEN bytes. */
static int
iso_pvd(imp, rootdr)
struct isomount *imp;
unsigned char   *rootdr;
{
    struct buf    *bp;
    unsigned char *p;
    long           sec;
    int            lbs;
    int            i;
    int            error;

    for (sec = ISO_VD_SECTOR; sec < 100L; sec++) {
        error = bread(imp->im_devvp, sec * (long)(ISO_SECSIZE / FS_BLKSIZE),
                      &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        p = (unsigned char *)bp->b_addr;
        if (p[ISO_VD_ID] != 'C' || p[ISO_VD_ID + 1] != 'D' ||
            p[ISO_VD_ID + 2] != '0' || p[ISO_VD_ID + 3] != '0' ||
            p[ISO_VD_ID + 4] != '1' || p[ISO_VD_TYPE] == ISO_VD_END) {
            brelse(bp);
            return (EINVAL);
        }
        if (p[ISO_VD_TYPE] == ISO_VD_PRIMARY)
            break;
        brelse(bp);
    }
    if (sec >= 100L)
        return (EINVAL);

    /* A LOGICAL BLOCK IS A POWER OF TWO FROM 512 TO 2048 (ISO 9660 6.2.2):
     * upstream's DEV_BSIZE..MAXBSIZE check, where the top is the sector, the
     * largest block a descriptor can describe. */
    lbs = isonum_723(&p[ISO_PVD_LBSIZE]);
    if (lbs != 512 && lbs != 1024 && lbs != 2048) {
        brelse(bp);
        return (EINVAL);
    }
    imp->im_bsize = lbs;
    for (imp->im_bshift = 0; (1 << imp->im_bshift) < lbs; imp->im_bshift++)
        ;
    imp->im_volsize = isonum_733(&p[ISO_PVD_VOLSIZE]);
    for (i = 0; i < ISO_ROOTDR_LEN; i++)
        rootdr[i] = p[ISO_PVD_ROOTDR + i];
    brelse(bp);
    return (0);
}


/* isofs_mount -- the vfsops entry.  `data' IS THE DEVICE PATH, staged by the
 * syscall layer, as it is for UFS and ProDOS. */
int
isofs_mount(mp, path, data, ndp)
struct mount     *mp;
char             *path;
char             *data;
struct nameidata *ndp;
{
    struct isomount *imp;
    struct vnode    *devvp;
    struct isoattr   ia;
    unsigned char    rootdr[ISO_ROOTDR_LEN];
    int              error;
    int              i;

    if ((mp->mnt_flag & MNT_RDONLY) == 0)
        return (EROFS);
    if (mp->mnt_flag & MNT_UPDATE)
        return (0);
    if (data == (char *)0)
        return (EINVAL);

    imp = (struct isomount *)0;
    for (i = 0; i < VFS_NMOUNT; i++) {
        if (iso_mpool[i].im_mountp == (struct mount *)0) {
            imp = &iso_mpool[i];
            break;
        }
    }
    if (imp == (struct isomount *)0)
        return (EMFILE);

    /* getmdev, which is isofs_mount's own: the device path to a block vnode,
     * ENOTBLK for anything else, and ENXIO for a major no driver claims. */
    ndp->ni_nameiop = LOOKUP | FOLLOW;
    ndp->ni_segflg  = UIO_SYSSPACE;
    ndp->ni_dirp    = data;
    error = namei(ndp);
    if (error)
        return (error);
    devvp = ndp->ni_vp;
    if (devvp->v_type != VBLK) {
        vrele(devvp);
        return (ENOTBLK);
    }
    if (major(devvp->v_rdev) >= NBLKDEV) {
        vrele(devvp);
        return (ENXIO);
    }
    if (devvp->v_specflags & SI_MOUNTEDON) {
        vrele(devvp);
        return (EBUSY);
    }

    imp->im_devvp = devvp;
    imp->im_dev   = devvp->v_rdev;
    error = iso_pvd(imp, rootdr);
    if (error) {
        vrele(devvp);
        return (error);
    }
    iso_parse(imp, rootdr, &ia);
    imp->im_rootext  = ia.ia_extent;
    imp->im_rootsize = ia.ia_size;

    imp->im_mountp = mp;
    mp->mnt_data   = (char *)imp;
    mp->mnt_op     = &isofs_vfsops;
    devvp->v_specflags |= SI_MOUNTEDON;

    for (i = 0; i < MNAMELEN; i++) {
        mp->mnt_stat.f_mntonname[i]   = 0;
        mp->mnt_stat.f_mntfromname[i] = 0;
    }
    for (i = 0; i < MNAMELEN - 1 && path[i]; i++)
        mp->mnt_stat.f_mntonname[i] = path[i];
    for (i = 0; i < MNAMELEN - 1 && data[i]; i++)
        mp->mnt_stat.f_mntfromname[i] = data[i];
    return (isofs_statfs(mp, &mp->mnt_stat));
}


/* isofs_statfs -- what df prints: the volume's size in logical blocks, all
 * of them used, and no file counts -- isofs_statfs's figures, where
 * f_files is the path table's size and means nothing to a reader. */
int
isofs_statfs(mp, sbp)
struct mount  *mp;
struct statfs *sbp;
{
    struct isomount *imp;
    int              i;

    imp = VFSTOISO(mp);
    sbp->f_type   = MOUNT_ISOFS;
    sbp->f_flags  = (short)(mp->mnt_flag & MNT_VISFLAGMASK);
    sbp->f_fsize  = (long)imp->im_bsize;
    sbp->f_bsize  = (long)imp->im_bsize;
    sbp->f_blocks = imp->im_volsize;
    sbp->f_bfree  = 0L;
    sbp->f_bavail = 0L;
    sbp->f_files  = 0L;
    sbp->f_ffree  = 0L;
    sbp->f_fsid   = (long)imp->im_dev;
    if (sbp != &mp->mnt_stat) {
        for (i = 0; i < MNAMELEN; i++) {
            sbp->f_mntonname[i]   = mp->mnt_stat.f_mntonname[i];
            sbp->f_mntfromname[i] = mp->mnt_stat.f_mntfromname[i];
        }
    }
    return (0);
}


/* isofs_unmount -- every node this mount produced goes or the unmount does
 * not, then the device reference and the pool slot.  isofs_unmount's, less
 * the forcible arm, which FGX's other filesystems refuse too. */
int
isofs_unmount(mp, forcibly)
struct mount *mp;
int           forcibly;
{
    struct isomount *imp;
    int              error;

    if (forcibly)
        return (EINVAL);
    imp = VFSTOISO(mp);
    if (imp == (struct isomount *)0)
        return (EINVAL);

    error = vflush(mp, (struct vnode *)0, 0);
    if (error)
        return (error);

    imp->im_devvp->v_specflags &= ~SI_MOUNTEDON;
    vrele(imp->im_devvp);
    mp->mnt_data   = (char *)0;
    mp->mnt_op     = (struct vfsops *)0;
    imp->im_mountp = (struct mount *)0;
    return (0);
}


/* isofs_root -- the root directory's node, locked: VFS_ROOT's contract.
 * Its attributes are its own "." record's, read by lookup when a node is
 * made; here, at the top, the record in the volume descriptor serves. */
int
isofs_root(mp, vpp)
struct mount  *mp;
struct vnode **vpp;
{
    struct isomount *imp;
    struct isonode  *ip;
    struct isoattr   ia;
    int              error;

    *vpp = (struct vnode *)0;
    imp = VFSTOISO(mp);
    ia.ia_extent = imp->im_rootext;
    ia.ia_size   = imp->im_rootsize;
    ia.ia_flags  = ISO_FL_DIR;
    ia.ia_interleaved = 0;
    ia.ia_mtime  = 0L;
    ia.ia_mode   = 0555;
    ia.ia_uid    = 0;
    ia.ia_gid    = 0;
    ia.ia_nlink  = 2;
    error = iso_iget(imp, ISO_BYTE(imp, imp->im_rootext), &ia, &ip);
    if (error)
        return (error);
    *vpp = ITOV(ip);
    return (0);
}


int
isofs_sync(mp, waitfor)
struct mount *mp;
int           waitfor;
{
    return (0);                 /* nothing is ever written */
}


/* isofs_init -- once, at module load, and mount(2) cannot find ISO 9660 until
 * its last line has run.  THE SIZE CHECK IS upstream's: the node lives in the
 * vnode's private area, and one that outgrew it would overwrite the next
 * vnode in the pool. */
int
isofs_init()
{
    int i;

    if (sizeof(struct isonode) > VN_MAXPRIVATE)
        kc_panic("isofs_init: vnode too small");
    iso_hashinit();
    for (i = 0; i < VFS_NMOUNT; i++)
        iso_mpool[i].im_mountp = (struct mount *)0;
    return (vfs_setvfsops(MOUNT_ISOFS, &isofs_vfsops));
}


struct vfsops isofs_vfsops = {
    isofs_mount,
    isofs_unmount,
    isofs_root,
    isofs_statfs,
    isofs_sync,
    isofs_init
};

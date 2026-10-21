/* FGX-Origin: original -- FGX code.  Its SHAPE is netbsd-0-9's
 * sys/isofs/isofs_vfsops.c (a read-only foreign volume behind vfsops) and
 * FGX's own ufs_vfsops.c (the mount pool, getmdev, unmount), consulted and not
 * ported; no BSD carried a ProDOS filesystem.
 * prodos_vfsops.c -- mounting a ProDOS volume.  ProDOS FST P2.
 *
 * WRITABLE WHEN ASKED.  A mount without MNT_RDONLY can write
 * (prodos_write.c); mount_prodos(8) asks for one only under `-o write'.  The
 * write half is its own module, prodosw.mod, and without it a writable mount
 * is refused with EROFS, which mount_prodos(8) answers by mounting read-only.
 */

#include "fsparam.h"
#include "vnode.h"
#include "specdev.h"
#include "buf.h"
#include "mount.h"
#include "namei.h"
#include "file.h"
#include "vfsops.h"
#include "prodos.h"

extern int           bread();
extern void          brelse();
extern int           namei();
extern void          vrele();
extern int           vflush();
extern int           vfs_setvfsops();
extern void          kc_panic();
extern void          pd_hashinit();
extern int           pdget();
extern struct vfsops prodos_vfsops;
extern struct pdwops *pd_wops;
int                  prodos_statfs();   /* below; prodos_mount ends in it */

static struct pdmount pd_mpool[VFS_NMOUNT];


/* pd_countfree -- the free blocks the volume bitmap records.  A SET BIT IS A
 * FREE BLOCK, bit 7 of byte 0 is block 0, and the map runs one 512-byte block
 * per 4096 volume blocks from bit_map_pointer.  Counted once, at mount, and
 * kept by pd_balloc after that. */
static int
pd_countfree(pmp)
struct pdmount *pmp;
{
    struct buf *bp;
    unsigned    left;
    unsigned    blk;
    unsigned    nbits;
    unsigned    i;
    int         off;
    int         c;
    int         error;

    pmp->pm_free = 0L;
    left = pmp->pm_totblks;
    for (blk = pmp->pm_bitmap; left != 0; blk++) {
        error = bread(pmp->pm_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        off = PD_BUFOFF(blk);
        nbits = left > 4096 ? 4096 : left;
        for (i = 0; i < nbits; i++) {
            c = bp->b_addr[off + (int)(i >> 3)];
            if (c & (0x80 >> (int)(i & 7)))
                pmp->pm_free++;
        }
        left -= nbits;
        brelse(bp);
    }
    return (0);
}


/* prodos_mount -- the vfsops entry.
 *
 * `data' IS THE DEVICE PATH, staged by the syscall layer, as it is for UFS.
 *
 * THE VOLUME IS CHECKED BEFORE ANYTHING IS WIRED: block 2 must be a volume
 * directory key block (no previous block, a $F header) whose header records
 * the entry geometry every ProDOS volume uses.  A device that is not a ProDOS
 * volume answers EINVAL, the errno ufs_mount gives a device that is not UFS.
 */
int
prodos_mount(mp, path, data, ndp)
struct mount     *mp;
char             *path;
char             *data;
struct nameidata *ndp;
{
    struct pdmount *pmp;
    struct vnode   *devvp;
    struct buf     *bp;
    unsigned char  *hp;
    int             error;
    int             i;

    /* THE UPDATE ARM KEEPS NOTHING TO CHANGE: whether the volume can be
     * written is read from mnt_flag at each write, so moving between
     * read-only and writable is the flag itself. */
    if ((mp->mnt_flag & MNT_RDONLY) == 0 && pd_wops == (struct pdwops *)0)
        return (EROFS);
    if (mp->mnt_flag & MNT_UPDATE)
        return (0);
    if (data == (char *)0)
        return (EINVAL);

    pmp = (struct pdmount *)0;
    for (i = 0; i < VFS_NMOUNT; i++) {
        if (pd_mpool[i].pm_mountp == (struct mount *)0) {
            pmp = &pd_mpool[i];
            break;
        }
    }
    if (pmp == (struct pdmount *)0)
        return (EMFILE);

    /* getmdev, which is ufs_vfsops.c's and Reno's: the device path to a block
     * vnode, or ENOTBLK. */
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
    /* ALREADY CARRYING A MOUNT, OF ANY TYPE.  isofs's iso_mountedon asks the
     * same question before it reads a byte; the flag is set by every
     * filesystem's mount, so this also refuses a device UFS has. */
    if (devvp->v_specflags & SI_MOUNTEDON) {
        vrele(devvp);
        return (EBUSY);
    }

    error = bread(devvp, PD_BUFBLK(PD_VOLDIR_BLK), &bp);
    if (error) {
        brelse(bp);
        vrele(devvp);
        return (error);
    }
    hp = (unsigned char *)&bp->b_addr[PD_BUFOFF(PD_VOLDIR_BLK)];
    if (PD_GETW(&hp[PD_DB_PREV]) != 0 ||
        PD_STORAGE(&hp[PD_DB_ENTRIES]) != PD_ST_VOLHDR ||
        hp[PD_DB_ENTRIES + PD_H_ENTRYLEN] != PD_ENTLEN ||
        hp[PD_DB_ENTRIES + PD_H_ENTPERBLK] != PD_ENTPERBLK) {
        brelse(bp);
        vrele(devvp);
        return (EINVAL);
    }
    pmp->pm_totblks = PD_GETW(&hp[PD_DB_ENTRIES + PD_VH_TOTBLKS]);
    pmp->pm_bitmap  = PD_GETW(&hp[PD_DB_ENTRIES + PD_VH_BITMAP]);
    brelse(bp);

    pmp->pm_devvp = devvp;
    pmp->pm_dev   = devvp->v_rdev;
    error = pd_countfree(pmp);
    if (error) {
        vrele(devvp);
        return (error);
    }

    pmp->pm_mountp = mp;
    mp->mnt_data   = (char *)pmp;
    mp->mnt_op     = &prodos_vfsops;
    devvp->v_specflags |= SI_MOUNTEDON;

    for (i = 0; i < MNAMELEN; i++) {
        mp->mnt_stat.f_mntonname[i]   = 0;
        mp->mnt_stat.f_mntfromname[i] = 0;
    }
    for (i = 0; i < MNAMELEN - 1 && path[i]; i++)
        mp->mnt_stat.f_mntonname[i] = path[i];
    for (i = 0; i < MNAMELEN - 1 && data[i]; i++)
        mp->mnt_stat.f_mntfromname[i] = data[i];
    return (prodos_statfs(mp, &mp->mnt_stat));
}


/* prodos_statfs -- what df prints.  ProDOS has blocks and no inodes, so the
 * file counts are zero rather than invented; f_bavail is f_bfree because
 * ProDOS reserves nothing. */
int
prodos_statfs(mp, sbp)
struct mount  *mp;
struct statfs *sbp;
{
    struct pdmount *pmp;
    int             i;

    pmp = VFSTOPD(mp);
    sbp->f_type   = MOUNT_PRODOS;
    sbp->f_flags  = (short)(mp->mnt_flag & MNT_VISFLAGMASK);
    sbp->f_fsize  = (long)PD_BLKSIZE;
    sbp->f_bsize  = (long)PD_BLKSIZE;
    sbp->f_blocks = (long)pmp->pm_totblks;
    sbp->f_bfree  = pmp->pm_free;
    sbp->f_bavail = pmp->pm_free;
    sbp->f_files  = 0L;
    sbp->f_ffree  = 0L;
    sbp->f_fsid   = (long)pmp->pm_dev;
    if (sbp != &mp->mnt_stat) {
        for (i = 0; i < MNAMELEN; i++) {
            sbp->f_mntonname[i]   = mp->mnt_stat.f_mntonname[i];
            sbp->f_mntfromname[i] = mp->mnt_stat.f_mntfromname[i];
        }
    }
    return (0);
}


/* prodos_unmount -- ufs_unmount's shape: every node this mount produced goes
 * or the unmount does not, then the device reference and the pool slot.  The
 * device is closed first, as Reno's ufs_unmount does: that drops its buffers
 * and lets a CD-ROM take another disc (spec_close). */
int
prodos_unmount(mp, forcibly)
struct mount *mp;
int           forcibly;
{
    struct pdmount *pmp;
    int             error;

    if (forcibly)
        return (EINVAL);
    pmp = VFSTOPD(mp);
    if (pmp == (struct pdmount *)0)
        return (EINVAL);

    error = vflush(mp, (struct vnode *)0, 0);
    if (error)
        return (error);

    pmp->pm_devvp->v_specflags &= ~SI_MOUNTEDON;
    (void)VOP_CLOSE(pmp->pm_devvp,
        (mp->mnt_flag & MNT_RDONLY) ? FREAD : FREAD | FWRITE, (char *)0);
    vrele(pmp->pm_devvp);
    mp->mnt_data   = (char *)0;
    mp->mnt_op     = (struct vfsops *)0;
    pmp->pm_mountp = (struct mount *)0;
    return (0);
}


/* prodos_root -- the volume directory's node, (2, 0), locked: VFS_ROOT's
 * contract, as ufs_root's. */
int
prodos_root(mp, vpp)
struct mount  *mp;
struct vnode **vpp;
{
    struct pdnode *pd;
    int            error;

    *vpp = (struct vnode *)0;
    error = pdget(VFSTOPD(mp), (unsigned)PD_VOLDIR_BLK, 0, &pd);
    if (error)
        return (error);
    *vpp = PDTOV(pd);
    return (0);
}


int
prodos_sync(mp, waitfor)
struct mount *mp;
int           waitfor;
{
    return (0);                 /* every write is a synchronous bwrite */
}


/* prodos_init -- once, at module load, and mount(2) cannot find ProDOS until
 * its last line has run.
 *
 * THE SIZE CHECK IS pcfs_init's: the node lives in the vnode's private area,
 * and a node that outgrew it would overwrite the next vnode in the pool. */
int
prodos_init()
{
    int i;

    if (sizeof(struct pdnode) > VN_MAXPRIVATE)
        kc_panic("prodos_init: vnode too small");
    pd_hashinit();
    for (i = 0; i < VFS_NMOUNT; i++)
        pd_mpool[i].pm_mountp = (struct mount *)0;
    return (vfs_setvfsops(MOUNT_PRODOS, &prodos_vfsops));
}


struct vfsops prodos_vfsops = {
    prodos_mount,
    prodos_unmount,
    prodos_root,
    prodos_statfs,
    prodos_sync,
    prodos_init
};

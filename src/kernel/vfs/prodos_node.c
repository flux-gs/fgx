/* FGX-Origin: original -- FGX code.  Its SHAPE is netbsd-0-9's
 * sys/pcfs/pcfs_denode.c (deget, reclaim) and FGX's own ufs_inode.c (the hash
 * and the lock), consulted and not ported; no BSD carried a ProDOS filesystem.
 * prodos_node.c -- the in-core ProDOS node: its hash, its lock, its lifetime,
 * the attributes stat(2) reads, the operations vector, and the handover from
 * the write half.  ProDOS FST P2.
 *
 * ONE NODE PER DIRECTORY-ENTRY LOCATION, which is the whole of this file.
 * prodos.h says what the key is and why it is not the key block.  Reading a
 * volume -- lookup, read, readdir -- is prodos_vnops.c's.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"
#include "dir.h"
#include "mount.h"
#include "vfsops.h"
#include "prodos.h"

extern int           bread();
extern void          brelse();
extern int           getnewvnode();
extern int           vget();
extern void          vref();
extern void          vrele();
extern void          vgone();
extern void          kc_sleep();
extern void          kc_wakeup();
extern int           kc_curpid();
extern int           kc_curuid();
extern int           kc_curgid();
extern void          kc_panic();
extern int           pd_lookup();       /* prodos_vnops.c */
extern int           pd_read();
extern int           pd_readdir();
extern int           pd_dirwalk();
extern int           pd_fork();
extern long          pd_stamp();
extern long          pd_dirstamp();
extern struct vnodeops prodos_vnodeops;     /* the vector, at the foot */
struct vnodeops       *pd_vops;             /* prodosw.mod's, once loaded */

/* PDHSZ IS UFS's INOHSZ AND FOR UFS's REASON: the ceiling is the 32-vnode
 * pool, not the volume, so a larger table would be empty chains. */
#define PDHSZ               16
#define PDHASH(dev, blk, idx) \
    ((((int)(dev)) + ((int)(blk)) + ((int)(idx))) & (PDHSZ - 1))

struct pdhead {
    struct pdnode *ph_chain[2];
};

static struct pdhead pd_hashtbl[PDHSZ];

void
pd_hashinit()
{
    int i;

    for (i = 0; i < PDHSZ; i++) {
        pd_hashtbl[i].ph_chain[0] = (struct pdnode *)&pd_hashtbl[i];
        pd_hashtbl[i].ph_chain[1] = (struct pdnode *)&pd_hashtbl[i];
    }
}

static void
pd_hashins(pd)
struct pdnode *pd;
{
    struct pdhead *ph;
    struct pdnode *next;

    ph = &pd_hashtbl[PDHASH(pd->pd_dev, pd->pd_dirblk, pd->pd_diridx)];
    next = ph->ph_chain[0];
    pd->pd_chain[0] = next;
    pd->pd_chain[1] = (struct pdnode *)ph;
    next->pd_chain[1] = pd;
    ph->ph_chain[0] = pd;
}

static void
pd_hashrem(pd)
struct pdnode *pd;
{
    struct pdnode *next;
    struct pdnode *prev;

    next = pd->pd_chain[0];
    prev = pd->pd_chain[1];
    prev->pd_chain[0] = next;
    next->pd_chain[1] = prev;
    pd->pd_chain[0] = pd;
    pd->pd_chain[1] = pd;
}


/* pd_lock / pd_unlock -- ufs_lock's contract exactly, including the panic on
 * locking against yourself, which turns a hang into a message. */
int
pd_lock(vp)
struct vnode *vp;
{
    struct pdnode *pd;

    pd = VTOPD(vp);
    while (pd->pd_flag & PDLOCKED) {
        if (pd->pd_lockholder == (short)kc_curpid())
            kc_panic("pd_lock: locking against myself");
        pd->pd_flag |= PDWANT;
        kc_sleep((char *)pd);
    }
    pd->pd_flag |= PDLOCKED;
    pd->pd_lockholder = (short)kc_curpid();
    return (0);
}

int
pd_unlock(vp)
struct vnode *vp;
{
    struct pdnode *pd;

    pd = VTOPD(vp);
    if ((pd->pd_flag & PDLOCKED) == 0)
        kc_panic("pd_unlock: not locked");
    pd->pd_lockholder = 0;
    pd->pd_flag &= ~PDLOCKED;
    if (pd->pd_flag & PDWANT) {
        pd->pd_flag &= ~PDWANT;
        kc_wakeup((char *)pd);
    }
    return (0);
}

int
pd_islocked(vp)
struct vnode *vp;
{
    return ((VTOPD(vp)->pd_flag & PDLOCKED) != 0);
}


/* pdget -- the node for (this mount, this location), locked and referenced.
 * pcfs's deget, less the FAT cache and the cluster arithmetic.
 *
 * `dirblk' and `idx' MUST ALREADY BE CANONICAL: a directory as (its key block,
 * 0), and an extended file's `._NAME' as its entry with PD_ADIDX set.  pcfs converts inside deget from the entry it is handed; here the caller
 * converts -- pd_dirscan and pd_parent -- because prodos_root has no entry to
 * convert from.
 *
 * THE ENTRY IS READ FROM DISK, not passed.  pcfs accepts an optional direntry
 * pointer so a lookup that already holds the block can skip the read; here
 * the block is in the buffer cache from the scan, and passing it would keep
 * that buffer across pdget's sleep.
 *
 * ON THE CHAIN AND LOCKED BEFORE THE READ, which is iget's order and deget's:
 * the read can sleep, and a second caller for the same location must find this
 * node and wait on its lock rather than build a second one.
 */
int
pdget(pmp, dirblk, idx, pdpp)
struct pdmount *pmp;
unsigned        dirblk;
int             idx;
struct pdnode **pdpp;
{
    struct pdhead *ph;
    struct pdnode *pd;
    struct vnode  *nvp;
    struct buf    *bp;
    unsigned char *ep;
    int            error;
    int            i;
    int            st;

    *pdpp = (struct pdnode *)0;

    ph = &pd_hashtbl[PDHASH(pmp->pm_dev, dirblk, idx)];
loop:
    for (pd = ph->ph_chain[0]; pd != (struct pdnode *)ph; pd = pd->pd_chain[0]) {
        /* pd_refcnt 0 IS AN ENTRY THAT IS GONE, and pcfs skips it for the
         * reason its comment gives: a new entry in the same slot must not
         * reach an unlinked file that is still open. */
        if (pd->pd_dev != pmp->pm_dev || pd->pd_refcnt == 0 ||
            pd->pd_dirblk != (unsigned short)dirblk || pd->pd_diridx != idx)
            continue;
        if (pd->pd_flag & PDLOCKED) {
            if (pd->pd_lockholder == (short)kc_curpid())
                kc_panic("pdget: locking against myself");
            pd->pd_flag |= PDWANT;
            kc_sleep((char *)pd);
            goto loop;
        }
        if (vget(PDTOV(pd)))
            goto loop;
        pd_lock(PDTOV(pd));
        *pdpp = pd;
        return (0);
    }

    error = getnewvnode(VT_PRODOS, pmp->pm_mountp,
                        pd_vops ? pd_vops : &prodos_vnodeops, &nvp);
    if (error)
        return (error);

    pd = VTOPD(nvp);
    pd->pd_vnode      = nvp;
    pd->pd_devvp      = pmp->pm_devvp;
    pd->pd_flag       = 0;
    pd->pd_lockholder = 0;
    pd->pd_dev        = pmp->pm_dev;
    pd->pd_dirblk     = (unsigned short)dirblk;
    pd->pd_diridx     = (short)idx;
    pd->pd_refcnt     = 1;
    pd->pd_pmp        = pmp;
    vref(pd->pd_devvp);         /* dropped in pd_reclaim, iget's pairing */

    pd_hashins(pd);
    pd_lock(nvp);

    error = bread(pmp->pm_devvp, PD_BUFBLK(dirblk), &bp);
    if (error) {
        brelse(bp);
        pd_hashrem(pd);
        pd_unlock(nvp);
        vrele(nvp);
        return (error);
    }
    ep = (unsigned char *)&bp->b_addr[PD_BUFOFF(dirblk) +
                                      PD_ENTOFF(idx & ~PD_ADIDX)];
    for (i = 0; i < PD_ENTLEN; i++)
        pd->pd_ent[i] = ep[i];
    brelse(bp);

    /* THE TYPE IS THE STORAGE NIBBLE.  A directory's canonical slot is its
     * header, $E, or $F for the volume; a subdirectory's ENTRY ($D) is never a
     * key, because the caller converted it.  Anything else is a file.  An
     * empty slot is refused: a location with no entry names nothing, and nor
     * does `._NAME' for an entry that has no resource fork. */
    st = PD_STORAGE(pd->pd_ent);
    if (st == PD_ST_DELETED ||
        ((idx & PD_ADIDX) && st != PD_ST_EXTENDED)) {
        pd_hashrem(pd);
        pd_unlock(nvp);
        vrele(nvp);
        return (ENOENT);
    }
    if (st == PD_ST_VOLHDR || st == PD_ST_SUBDIRHDR)
        nvp->v_type = VDIR;
    else
        nvp->v_type = VREG;
    if (dirblk == PD_VOLDIR_BLK && idx == 0)
        nvp->v_flag |= VROOT;   /* in pdget and not prodos_root, iget's reason */

    /* THE BYTES A READ RETURNS: the entry's own for every file but an
     * extended one, whose fork is behind one more block and is read by
     * pd_fork when a stat or a read first asks. */
    pd->pd_fst  = st;
    pd->pd_fkey = PD_GETW(&pd->pd_ent[PD_E_KEYPTR]);
    pd->pd_feof = (long)PD_GETW(&pd->pd_ent[PD_E_EOF]) |
                  ((long)pd->pd_ent[PD_E_EOF + 2] << 16);
    if (st == PD_ST_EXTENDED)
        pd->pd_fst = -1;

    *pdpp = pd;
    return (0);
}


/* pd_twin -- the other in-core node on `pd''s entry, or null: a file and its
 * `._NAME' are two nodes on one entry, their indexes differing only by
 * PD_ADIDX.  It must be of the same generation -- both named, or both
 * unlinked -- because a new entry can take the slot of one that is unlinked
 * and still open. */
struct pdnode *
pd_twin(pd)
struct pdnode *pd;
{
    struct pdhead *ph;
    struct pdnode *tw;
    int            idx;

    idx = pd->pd_diridx ^ PD_ADIDX;
    ph  = &pd_hashtbl[PDHASH(pd->pd_dev, pd->pd_dirblk, idx)];
    for (tw = ph->ph_chain[0]; tw != (struct pdnode *)ph; tw = tw->pd_chain[0])
        if (tw->pd_dev == pd->pd_dev && tw->pd_dirblk == pd->pd_dirblk &&
            tw->pd_diridx == idx &&
            (tw->pd_refcnt == 0) == (pd->pd_refcnt == 0))
            return (tw);
    return ((struct pdnode *)0);
}


/* pd_rekey -- refile `pd', and its twin, under the entry location (blk,
 * idx) that a rename moved its entry to: pcfs's fixup for a key that names
 * where the entry is (prodos.h).  A node left under its old key would be a
 * second node for one file the next time a lookup reached it. */
void
pd_rekey(pd, blk, idx)
struct pdnode *pd;
unsigned       blk;
int            idx;
{
    struct pdnode *tw;

    tw = pd_twin(pd);
    pd_hashrem(pd);
    pd->pd_dirblk = (unsigned short)blk;
    pd->pd_diridx = (short)idx;
    pd_hashins(pd);
    if (tw) {
        pd_hashrem(tw);
        tw->pd_dirblk = (unsigned short)blk;
        tw->pd_diridx = (short)(idx | PD_ADIDX);
        pd_hashins(tw);
    }
}


/* pd_entsync -- after `pd' rewrote its entry, give the same bytes to its
 * twin, which would otherwise stat a stale EOF, date and blocks used. */
int
pd_entsync(pd)
struct pdnode *pd;
{
    struct pdnode *tw;
    int            i;

    tw = pd_twin(pd);
    if (tw) {
        for (i = 0; i < PD_ENTLEN; i++)
            tw->pd_ent[i] = pd->pd_ent[i];
        tw->pd_fst = -1;
    }
    return (0);
}


/* THE WRITE HALF's ENTRY POINTS, null until prodosw.mod hands them over. */
struct pdwops *pd_wops;


/* pd_setwriteops -- prodosw.mod's mod_init hands over its entry points and an
 * empty vector of its own.  That vector takes this one's slots, then the write
 * half's in the writing slots, and every node made from then on uses it.  The
 * pointers carry their own module's bank, so it dispatches straight to either.
 * The vector a module was built with is never written, as vfs_setvfsops leaves
 * each filesystem's own. */
int
pd_setwriteops(w, v)
struct pdwops   *w;
struct vnodeops *v;
{
    *v = prodos_vnodeops;
    v->vn_write   = w->w_write;
    v->vn_close   = w->w_close;
    v->vn_create  = w->w_create;
    v->vn_mkdir   = w->w_create;
    v->vn_remove  = w->w_remove;
    v->vn_rmdir   = w->w_remove;
    v->vn_rename  = w->w_rename;
    v->vn_setattr = w->w_setattr;
    pd_wops = w;
    pd_vops = v;
    return (0);
}


/* pd_inactive -- the last reference went.  A node a write revised and no
 * close rippled ripples now.
 *
 * A NODE WHOSE ENTRY IS GONE GIVES ITS BLOCKS BACK NOW, which is
 * pcfs_inactive's detrunc and ufs_inactive's itrunc: unlink and rmdir take the
 * name away (pd_remove) and leave the blocks to the last reference, so a file
 * unlinked while open keeps working until it is closed.  Not while its twin
 * is still in use -- `._NAME' open reads the same file's blocks -- and the
 * twin frees them when it goes.  Then the node is reclaimed rather than left
 * in the hash, pcfs_inactive's tail. */
int
pd_inactive(vp)
struct vnode *vp;
{
    struct pdnode *pd;
    struct pdnode *tw;

    pd = VTOPD(vp);
    if ((pd->pd_flag & PDMOD) && pd_wops)
        (void)(*pd_wops->w_ripple)(pd);
    if (pd->pd_refcnt == 0 && pd_wops &&
        (vp->v_mount->mnt_flag & MNT_RDONLY) == 0) {
        tw = pd_twin(pd);
        if (tw == (struct pdnode *)0 || PDTOV(tw)->v_usecount == 0) {
            (void)(*pd_wops->w_free)(pd);
            if (tw)
                tw->pd_ent[PD_E_STNL] = 0;
        }
    }
    if (vp->v_usecount == 0 && pd->pd_refcnt == 0)
        vgone(vp);
    return (0);
}

/* pd_reclaim -- the vnode is being given to someone else.  pcfs_reclaim:
 * off the hash, and the device reference goes. */
int
pd_reclaim(vp)
struct vnode *vp;
{
    struct pdnode *pd;

    pd = VTOPD(vp);
    pd_hashrem(pd);
    if (pd->pd_devvp) {
        vrele(pd->pd_devvp);
        pd->pd_devvp = (struct vnode *)0;
    }
    pd->pd_flag = 0;
    return (0);
}


/* pd_mode -- a node's permission bits, from its ACCESS BYTE ("Beneath Apple
 * ProDOS" p. 4-9: $80 destroy, $40 rename, $20 backup, $02 write, $01 read).
 *
 * THE MAPPING IS A DECISION, NOT A CORRESPONDENCE, and this is it: read ($01)
 * is r for owner, group and other; write ($02) is w for the owner alone; a
 * directory is searchable wherever it is readable; a file is never
 * executable, because nothing on a ProDOS volume is an FGX program.  Destroy
 * and rename have no file-mode counterpart -- Unix puts both in the
 * DIRECTORY's w -- and backup is not a permission.  A directory's byte is its
 * header's, the volume's the volume header's.  mount_prodos(8) states it. */
static int
pd_mode(vp)
struct vnode *vp;
{
    int acc;
    int m;

    acc = VTOPD(vp)->pd_ent[PD_E_ACCESS];
    m = 0;
    if (acc & 0x01)
        m = (vp->v_type == VDIR) ? 0555 : 0444;
    if (acc & 0x02)
        m |= 0200;
    return (m);
}


/* pd_access -- ufs_access's check against pd_mode, and EROFS for a write to
 * a read-only mount.
 *
 * A READ-ONLY MOUNT refuses VWRITE before any mode is asked.  vn_open's
 * vn_writechk has already made that test for an open (Reno kern/vfs_vnops.c,
 * vn_writechk); this repeats it for a caller that asks VOP_ACCESS directly.
 * Otherwise it is ufs_access exactly: the super-user always gets access, and
 * anyone else is checked against ONE of owner, group and other, by shifts of
 * 0, 3 and 6.  Every node is owned by uid 0 and gid 0, as netbsd-0-9's isofs
 * and pcfs report theirs, so only root is the owner and only gid 0 the group. */
int
pd_access(vp, mode, cred)
struct vnode *vp;
int           mode;
char         *cred;
{
    if ((mode & VWRITE) && (vp->v_mount->mnt_flag & MNT_RDONLY))
        return (EROFS);
    if (kc_curuid() == 0)
        return (0);
    mode >>= 3;
    if (kc_curgid() != 0)
        mode >>= 3;
    if ((pd_mode(vp) & mode) != 0)
        return (0);
    return (EACCES);
}


/* pd_getattr -- what stat(2) says about a node.  Every field is assigned, as
 * ufs_getattr assigns them.
 *
 * va_fileid IS THE KEY BLOCK, isofs's answer (its inode number is the
 * extent), and NOT the node's key.  The key is (block, index), 20 bits, and
 * ino_t, st_ino and d_ino are 16: any projection of it aliases on a volume
 * past 4096 blocks, and one that truncates to 0 is skipped by every readdir
 * consumer.  A block number is 16 bits on ProDOS too, a key block belongs to
 * exactly one file or directory, and ProDOS 8's create allocates one for every
 * entry (MliSrc.aii `cralcblk'), so it is unique and never 0.  A directory's
 * key block is its own key's block; the root is 2, UFS's ROOTINO.  An
 * extended file's `._NAME' is numbered by its resource fork's key block, which
 * is as much that file's alone.
 *
 * WHAT IT COSTS IS STABILITY UNDER WRITE: promotion (MliSrc.aii `swapdown')
 * and a shrinking set_eof (`detree') move a file's key block, so a file's
 * inode number changes when it grows past 512 bytes or 128 KB.  A directory's
 * never does.  readdir reports the same number from the entry's key_pointer,
 * with no read.
 *
 * WHAT IS SYNTHESIZED, each named with the increment that replaces it:
 *   mode    pd_mode's, from the access byte.
 *   nlink   2 and 1, which is design section 6's answer and is final:
 *           ProDOS has no hard links.
 *   uid/gid 0 for every node, as isofs and pcfs in netbsd-0-9 report theirs;
 *           neither takes an owner as a mount option.
 *   times   all three the modification stamp, as pcfs_getattr sets all three
 *           from its one DOS date: ProDOS keeps no access time and its other
 *           stamp is a creation time, which st_ctime is not.  A directory's
 *           is pd_dirstamp's.
 *   size    a file's EOF, which is exact -- an extended file's data fork's,
 *           and its `._NAME''s resource fork's plus the AppleDouble header.
 *           A directory's is two DIRBLKSIZ per block of its chain, the length
 *           pd_readdir renders.
 *
 * CHDIR NEEDS IT: the syscall stats the target and requires S_IFDIR before it reaches vfs_chdir, so a filesystem
 * with no getattr cannot be stood in. */
int
pd_getattr(vp, vap, cred)
struct vnode *vp;
struct vattr *vap;
char         *cred;
{
    struct pdnode *pd;
    unsigned char *e;
    unsigned       blk;
    unsigned       n;
    int            error;

    pd = VTOPD(vp);
    e  = pd->pd_ent;
    n  = 0;
    if (vp->v_type == VDIR)
        error = pd_dirwalk(pd, pd->pd_pmp->pm_totblks, &blk, &n);
    else
        error = pd_fork(pd);
    if (error)
        return (error);
    vap->va_type      = vp->v_type;
    vap->va_nlink     = (vp->v_type == VDIR) ? 2 : 1;
    vap->va_mode      = pd_mode(vp);
    vap->va_uid       = 0;
    vap->va_gid       = 0;
    vap->va_fsid      = (long)pd->pd_dev;
    if (vp->v_type == VDIR) {
        vap->va_fileid = (long)pd->pd_dirblk;
        vap->va_size   = (off_t)n * (off_t)(2 * DIRBLKSIZ);
    } else if (pd->pd_diridx & PD_ADIDX) {
        vap->va_fileid = (long)pd->pd_fkey;
        vap->va_size   = pd->pd_feof + (off_t)PD_ADHDRLEN;
    } else {
        vap->va_fileid = (long)PD_GETW(&e[PD_E_KEYPTR]);
        vap->va_size   = pd->pd_feof;
    }
    vap->va_blocksize = (long)PD_BLKSIZE;
    vap->va_mtime     = (vp->v_type == VDIR) ? pd_dirstamp(pd) :
                        pd_stamp(&e[PD_E_MODTIME]);
    vap->va_atime     = vap->va_mtime;
    vap->va_ctime     = vap->va_mtime;
    vap->va_flags     = 0;
    vap->va_rdev      = (dev_t)NODEV;
    return (0);
}


int
pd_enotsup()
{
    return (ENOTSUP);
}


/* pd_select -- select(2) on a ProDOS file.  ufs_select's answer, for
 * ufs_select's reason: a file never blocks, so it is ready for every `which',
 * which is what 4.3BSD-Reno's ufs_select and 2.11BSD's ino_select answer.
 * ProDOS has no BSD counterpart of its own to read.  A select routine and not
 * pd_enotsup, because vfs_select reads the return as a BOOLEAN.
 */
int
pd_select(vp, which, fflags, cred)
    struct vnode *vp;
    int    which;
    int    fflags;
    char  *cred;
{
    return (1);
}

int
pd_nullop()
{
    return (0);
}

/* THE VECTOR, in vnode.h's order.  The slots that change a volume answer
 * ENOTSUP -- and close does nothing -- in nodes made before pd_setwriteops
 * gives prodosw.mod's copy to pdget.  open
 * and close succeed because the VFS calls them on every vnode it hands a
 * descriptor. */
struct vnodeops prodos_vnodeops = {
    pd_lookup,
    pd_enotsup,     /* create: pd_setwriteops */
    pd_enotsup,     /* mknod */
    pd_nullop,      /* open */
    pd_nullop,      /* close: pd_setwriteops */
    pd_access,
    pd_getattr,
    pd_enotsup,     /* setattr: pd_setwriteops */
    pd_read,
    pd_enotsup,     /* write: pd_setwriteops */
    pd_enotsup,     /* ioctl */
    pd_select,      /* select */
    pd_enotsup,     /* mmap */
    pd_nullop,      /* fsync */
    pd_nullop,      /* seek */
    pd_enotsup,     /* remove: pd_setwriteops */
    pd_enotsup,     /* link */
    pd_enotsup,     /* rename: pd_setwriteops */
    pd_enotsup,     /* mkdir: pd_setwriteops, pd_create */
    pd_enotsup,     /* rmdir: pd_setwriteops, pd_remove */
    pd_enotsup,     /* symlink */
    pd_readdir,
    pd_enotsup,     /* readlink */
    pd_nullop,      /* abortop */
    pd_inactive,
    pd_reclaim,
    pd_lock,
    pd_unlock,
    pd_enotsup,     /* bmap */
    pd_enotsup,     /* strategy */
    pd_nullop,      /* print */
    pd_islocked
};

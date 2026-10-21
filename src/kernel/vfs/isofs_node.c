/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: netbsd-0-9 sys/isofs/isofs_node.c, sys/isofs/isofs_vnops.c
 *   iso_iget, isofs_inactive, isofs_reclaim, iso_ilock/iso_iunlock and
 *   isofs_getattr, in FGX's VFS terms (prodos_node.c's shape).  FGX deltas:
 *   the node is numbered by Lite2's isodirino rather than the extent
 *   (isofs.h); it is made from parsed attributes rather than a pointer into a
 *   directory buffer; an access check where netbsd-0-9's isofs_access grants
 *   everything; and a directory's size is the length readdir renders.
 *   Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* isofs_node.c -- the in-core ISO 9660 node: its hash, its lock, its
 * lifetime, the attributes stat(2) reads and the operations vector.  Reading
 * a volume -- lookup, read, readdir -- is isofs_vnops.c's.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"
#include "dir.h"
#include "mount.h"
#include "vfsops.h"
#include "isofs.h"

extern int           getnewvnode();
extern int           vget();
extern void          vref();
extern void          vrele();
extern void          kc_sleep();
extern void          kc_wakeup();
extern int           kc_curpid();
extern int           kc_curuid();
extern int           kc_curgid();
extern void          kc_panic();
extern int           iso_lookup();      /* isofs_vnops.c */
extern int           iso_read();
extern int           iso_readdir();
extern int           iso_readlink();
extern long          iso_dirsize();
extern struct vnodeops isofs_vnodeops;  /* the vector, at the foot */

/* ISOHSZ IS UFS's INOHSZ AND FOR UFS's REASON: the ceiling is the 32-vnode
 * pool, not the volume, so a larger table would be empty chains.  netbsd-0-9
 * sized it 512. */
#define ISOHSZ              16
#define ISOHASH(dev, ino) \
    ((((int)(dev)) + (int)((ino) >> 5)) & (ISOHSZ - 1))

struct isohead {
    struct isonode *ih_chain[2];
};

static struct isohead iso_hashtbl[ISOHSZ];

void
iso_hashinit()
{
    int i;

    for (i = 0; i < ISOHSZ; i++) {
        iso_hashtbl[i].ih_chain[0] = (struct isonode *)&iso_hashtbl[i];
        iso_hashtbl[i].ih_chain[1] = (struct isonode *)&iso_hashtbl[i];
    }
}

static void
iso_hashins(ip)
struct isonode *ip;
{
    struct isohead *ih;
    struct isonode *next;

    ih = &iso_hashtbl[ISOHASH(ip->i_dev, ip->i_number)];
    next = ih->ih_chain[0];
    ip->i_chain[0] = next;
    ip->i_chain[1] = (struct isonode *)ih;
    next->i_chain[1] = ip;
    ih->ih_chain[0] = ip;
}

static void
iso_hashrem(ip)
struct isonode *ip;
{
    struct isonode *next;
    struct isonode *prev;

    next = ip->i_chain[0];
    prev = ip->i_chain[1];
    prev->i_chain[0] = next;
    next->i_chain[1] = prev;
    ip->i_chain[0] = ip;
    ip->i_chain[1] = ip;
}


/* iso_lock / iso_unlock -- iso_ilock's contract, which is ufs_lock's,
 * including the panic on locking against yourself. */
int
iso_lock(vp)
struct vnode *vp;
{
    struct isonode *ip;

    ip = VTOI(vp);
    while (ip->i_flag & ILOCKED) {
        if (ip->i_lockholder == (short)kc_curpid())
            kc_panic("iso_lock: locking against myself");
        ip->i_flag |= IWANT;
        kc_sleep((char *)ip);
    }
    ip->i_flag |= ILOCKED;
    ip->i_lockholder = (short)kc_curpid();
    return (0);
}

int
iso_unlock(vp)
struct vnode *vp;
{
    struct isonode *ip;

    ip = VTOI(vp);
    if ((ip->i_flag & ILOCKED) == 0)
        kc_panic("iso_unlock: not locked");
    ip->i_lockholder = 0;
    ip->i_flag &= ~ILOCKED;
    if (ip->i_flag & IWANT) {
        ip->i_flag &= ~IWANT;
        kc_wakeup((char *)ip);
    }
    return (0);
}

int
iso_islocked(vp)
struct vnode *vp;
{
    return ((VTOI(vp)->i_flag & ILOCKED) != 0);
}


/* iso_iget -- the node numbered `ino' on this mount, locked and referenced.
 * netbsd-0-9's iso_iget.
 *
 * `ia' DESCRIBES IT, and is read only when the node is made: one already in
 * core is the same file, whatever led to it.
 *
 * ON THE CHAIN AND LOCKED BEFORE IT IS FILLED, iget's order: getnewvnode can
 * sleep, and a second caller for the same number must find this node and wait
 * on its lock rather than build another. */
int
iso_iget(imp, ino, ia, ipp)
struct isomount *imp;
long             ino;
struct isoattr  *ia;
struct isonode **ipp;
{
    struct isohead *ih;
    struct isonode *ip;
    struct vnode   *nvp;
    int             error;

    *ipp = (struct isonode *)0;

    ih = &iso_hashtbl[ISOHASH(imp->im_dev, ino)];
loop:
    for (ip = ih->ih_chain[0]; ip != (struct isonode *)ih; ip = ip->i_chain[0]) {
        if (ip->i_dev != imp->im_dev || ip->i_number != ino)
            continue;
        if (ip->i_flag & ILOCKED) {
            if (ip->i_lockholder == (short)kc_curpid())
                kc_panic("iso_iget: locking against myself");
            ip->i_flag |= IWANT;
            kc_sleep((char *)ip);
            goto loop;
        }
        if (vget(ITOV(ip)))
            goto loop;
        iso_lock(ITOV(ip));
        *ipp = ip;
        return (0);
    }

    error = getnewvnode(VT_ISOFS, imp->im_mountp, &isofs_vnodeops, &nvp);
    if (error)
        return (error);

    ip = VTOI(nvp);
    ip->i_vnode      = nvp;
    ip->i_devvp      = imp->im_devvp;
    ip->i_flag       = 0;
    ip->i_lockholder = 0;
    ip->i_dev        = imp->im_dev;
    ip->i_number     = ino;
    ip->i_mnt        = imp;
    ip->i_attr       = *ia;
    vref(ip->i_devvp);          /* dropped in iso_reclaim, iget's pairing */

    iso_hashins(ip);
    iso_lock(nvp);

    if (ia->ia_flags & ISO_FL_DIR)
        nvp->v_type = VDIR;
    else if ((ia->ia_mode & 0170000) == 0120000)
        nvp->v_type = VLNK;     /* a Rock Ridge symbolic link */
    else
        nvp->v_type = VREG;
    if (ino == ISO_BYTE(imp, imp->im_rootext))
        nvp->v_flag |= VROOT;   /* in iget and not isofs_root, iget's reason */

    *ipp = ip;
    return (0);
}


/* iso_inactive -- the last reference went.  NOTHING TO DO, and netbsd-0-9
 * says why it does not reclaim here: "It's too much penalty for cdrom"
 * (isofs_inactive) -- a node left in the hash is a lookup that needs no
 * directory read the next time. */
int
iso_inactive(vp)
struct vnode *vp;
{
    VTOI(vp)->i_flag = 0;
    return (0);
}

/* iso_reclaim -- the vnode is being given to someone else: off the hash, and
 * the device reference goes.  isofs_reclaim. */
int
iso_reclaim(vp)
struct vnode *vp;
{
    struct isonode *ip;

    ip = VTOI(vp);
    iso_hashrem(ip);
    if (ip->i_devvp) {
        vrele(ip->i_devvp);
        ip->i_devvp = (struct vnode *)0;
    }
    ip->i_flag = 0;
    return (0);
}


/* iso_ino16 -- a node number as the 16-bit ino_t that stat and readdir
 * carry.  Directory records are at least 34 bytes apart, so >> 5 keeps every
 * record within 2 MB distinct; the high bits are folded in, and 0 -- which
 * readdir's consumers skip as an unused entry -- becomes 1. */
unsigned
iso_ino16(ino)
long ino;
{
    unsigned n;

    n = (unsigned)(ino >> 5) ^ (unsigned)(ino >> 21);
    return (n == 0 ? 1 : n);
}


/* iso_access -- ufs_access's check against the node's mode, and EROFS for
 * any write: every ISO 9660 mount is read-only.  netbsd-0-9's isofs_access
 * returns 0 for everything; Lite2's cd9660_access makes this check. */
int
iso_access(vp, mode, cred)
struct vnode *vp;
int           mode;
char         *cred;
{
    struct isoattr *ia;

    if (mode & VWRITE)
        return (EROFS);
    if (kc_curuid() == 0)
        return (0);
    ia = &VTOI(vp)->i_attr;
    if (kc_curuid() != (int)ia->ia_uid) {
        mode >>= 3;
        if (kc_curgid() != (int)ia->ia_gid)
            mode >>= 3;
    }
    if ((ia->ia_mode & mode) != 0)
        return (0);
    return (EACCES);
}


/* iso_getattr -- what stat(2) says about a node.  isofs_getattr's fields,
 * every one assigned, as ufs_getattr assigns them.
 *
 *   size    a file's data length; a directory's is the length readdir
 *           renders, not the bytes on the volume (iso_dirsize).
 *   times   all three the one ISO 9660 records -- or Rock Ridge's TF.
 *   nlink   2 and 1 without Rock Ridge, as netbsd-0-9 answers. */
int
iso_getattr(vp, vap, cred)
struct vnode *vp;
struct vattr *vap;
char         *cred;
{
    struct isonode *ip;
    struct isoattr *ia;

    ip = VTOI(vp);
    ia = &ip->i_attr;
    vap->va_type      = vp->v_type;
    vap->va_nlink     = ia->ia_nlink;
    vap->va_mode      = ia->ia_mode & 07777;
    vap->va_uid       = ia->ia_uid;
    vap->va_gid       = ia->ia_gid;
    vap->va_fsid      = (long)ip->i_dev;
    vap->va_fileid    = (long)iso_ino16(ip->i_number);
    vap->va_size      = (vp->v_type == VDIR) ? iso_dirsize(ip) : ia->ia_size;
    vap->va_blocksize = (long)ip->i_mnt->im_bsize;
    vap->va_mtime     = ia->ia_mtime;
    vap->va_atime     = ia->ia_mtime;
    vap->va_ctime     = ia->ia_mtime;
    vap->va_flags     = 0;
    vap->va_rdev      = (dev_t)NODEV;
    return (0);
}


int
iso_erofs()
{
    return (EROFS);
}

int
iso_enotsup()
{
    return (ENOTSUP);
}

/* iso_select -- a file never blocks, so it is ready for every `which':
 * ufs_select's and pd_select's answer.  netbsd-0-9's isofs_select is the
 * same `return (1)'. */
int
iso_select(vp, which, fflags, cred)
struct vnode *vp;
int           which;
int           fflags;
char         *cred;
{
    return (1);
}

int
iso_nullop()
{
    return (0);
}

/* THE VECTOR, in vnode.h's order, and netbsd-0-9's isofs_vnodeops slot for
 * slot: everything that would change the volume answers EROFS, where upstream
 * says enodev. */
struct vnodeops isofs_vnodeops = {
    iso_lookup,
    iso_erofs,      /* create */
    iso_erofs,      /* mknod */
    iso_nullop,     /* open */
    iso_nullop,     /* close */
    iso_access,
    iso_getattr,
    iso_erofs,      /* setattr */
    iso_read,
    iso_erofs,      /* write */
    iso_enotsup,    /* ioctl */
    iso_select,
    iso_enotsup,    /* mmap */
    iso_nullop,     /* fsync */
    iso_nullop,     /* seek */
    iso_erofs,      /* remove */
    iso_erofs,      /* link */
    iso_erofs,      /* rename */
    iso_erofs,      /* mkdir */
    iso_erofs,      /* rmdir */
    iso_erofs,      /* symlink */
    iso_readdir,
    iso_readlink,
    iso_nullop,     /* abortop */
    iso_inactive,
    iso_reclaim,
    iso_lock,
    iso_unlock,
    iso_enotsup,    /* bmap */
    iso_enotsup,    /* strategy */
    iso_nullop,     /* print */
    iso_islocked
};

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/dead_vnops.c
 *   Ported from kern/dead_vnops.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 */
/* dead_vnops.c -- the operations vector a reclaimed vnode wears, from
 * 4.3BSD-Reno kern/dead_vnops.c.
 *
 * WHAT IT IS FOR.  vclean tears a vnode away from its filesystem so the vnode
 * can be reused for a different file.  Anyone still holding a reference to it
 * -- an open descriptor, a cached name, a process's cwd -- has a pointer that
 * is still valid memory and no longer means what it meant.  Reno's answer is
 * not to detect that at every call site but to swap the OPS VECTOR: the vnode
 * keeps working as a vnode, and every operation on it fails.
 *
 * That is why this file exists rather than a null check in vclean's callers.
 * A check has to be written at every one of thirty-two entry points and stays
 * correct only until someone adds the thirty-third; a vector is exhaustive by
 * construction, because the vector IS the set of entry points.
 *
 * THE THREE FAILURE MODES ARE NOT INTERCHANGEABLE, and Reno's choice per slot
 * is kept exactly:
 *
 *   dead_ebadf   -- EBADF.  The caller has a descriptor that no longer refers
 *                   to anything.  A user-visible, recoverable error.
 *   dead_nullop  -- 0.  The operation is meaningless on a dead vnode but
 *                   succeeding costs nothing: closing an already-dead file,
 *                   syncing a file with nothing to sync.  Returning an error
 *                   here would make close(2) fail on a perfectly ordinary
 *                   sequence.
 *   dead_badop   -- panic.  The operation could not have been reached without
 *                   a namei lookup, and namei cannot return a dead vnode.
 *                   Reaching one of these means the vnode layer is already
 *                   inconsistent, and continuing would create a file on a
 *                   filesystem that no longer owns the vnode.
 *
 * chkvnlock is the reason several of these forward rather than fail.  A vnode
 * under VXLOCK is MID-teardown, not dead: the caller arrived while vclean was
 * running.  Waiting for the lock to clear and then re-dispatching sends the
 * call to whatever vector the vnode ended up with -- dead_vnodeops if the
 * teardown completed, the filesystem's own if it did not.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"

extern void kc_sleep();
extern void kc_panic();
extern void biodone();

int dead_lookup();
int dead_open();
int dead_read();
int dead_write();
int dead_ioctl();
int dead_select();
int dead_strategy();
int dead_lock();
int dead_bmap();
int dead_print();
int dead_ebadf();
int dead_badop();
int dead_nullop();

static int chkvnlock();

/* Positional, in the order struct vnodeops declares.  The comments are the
 * check: a slot inserted in the header without one added here shifts every
 * entry below it, and a shifted vector is a call that lands on the wrong
 * operation rather than a compile error. */
struct vnodeops dead_vnodeops = {
    dead_lookup,        /* lookup */
    dead_badop,         /* create */
    dead_badop,         /* mknod */
    dead_open,          /* open */
    dead_nullop,        /* close */
    dead_ebadf,         /* access */
    dead_ebadf,         /* getattr */
    dead_ebadf,         /* setattr */
    dead_read,          /* read */
    dead_write,         /* write */
    dead_ioctl,         /* ioctl */
    dead_select,        /* select */
    dead_badop,         /* mmap */
    dead_nullop,        /* fsync */
    dead_nullop,        /* seek */
    dead_badop,         /* remove */
    dead_badop,         /* link */
    dead_badop,         /* rename */
    dead_badop,         /* mkdir */
    dead_badop,         /* rmdir */
    dead_badop,         /* symlink */
    dead_ebadf,         /* readdir */
    dead_ebadf,         /* readlink */
    dead_badop,         /* abortop */
    dead_nullop,        /* inactive */
    dead_nullop,        /* reclaim */
    dead_lock,          /* lock */
    dead_nullop,        /* unlock */
    dead_bmap,          /* bmap */
    dead_strategy,      /* strategy */
    dead_print,         /* print */
    dead_nullop         /* islocked */
};

/* Wait out a teardown in progress.  Returns 1 if it actually waited, which is
 * the caller's signal that the vnode may now have a DIFFERENT vector and the
 * operation should be re-dispatched rather than failed. */
static int
chkvnlock(vp)
    register struct vnode *vp;
{
    int locked;

    locked = 0;
    while (vp->v_flag & VXLOCK) {
        vp->v_flag |= VXWANT;
        kc_sleep((char *)vp);
        locked = 1;
    }
    return (locked);
}

/* Lookup always fails.  Reno fills in ndp->ni_dvp/ni_vp; nameidata arrives at
 * 1.6, so this returns the errno and nothing else -- the value is what the
 * caller acts on either way. */
int
dead_lookup(vp)
    struct vnode *vp;
{
    return (ENOTDIR);
}

/* Open fails as if the device had never existed, which is what a caller that
 * raced an unlink should see. */
int
dead_open(vp, mode)
    struct vnode *vp;
    int mode;
{
    return (ENXIO);
}

int
dead_read(vp)
    register struct vnode *vp;
{
    if (chkvnlock(vp))
        kc_panic("dead_read: lock");
    /* END OF FILE for a character device, an error for anything else.  A
     * character device that goes away mid-read has simply ended; a regular
     * file that does is a failure the reader has to see. */
    if (vp->v_type != VCHR)
        return (EIO);
    return (0);
}

int
dead_write(vp)
    register struct vnode *vp;
{
    if (chkvnlock(vp))
        kc_panic("dead_write: lock");
    return (EIO);
}

int
dead_ioctl(vp, com, data, fflag, cred)
    struct vnode *vp;
    int com;
    char *data;
    int fflag;
    char *cred;
{
    if (!chkvnlock(vp))
        return (EBADF);
    return (VOP_IOCTL(vp, com, data, fflag, cred));
}

int
dead_select(vp)
    struct vnode *vp;
{
    /* READY, deliberately.  select must not block on a descriptor that will
     * never become ready again; reporting it ready is how the caller gets as
     * far as the read that tells it the truth. */
    return (1);
}

int
dead_strategy(bp)
    register struct buf *bp;
{
    if (bp->b_vp == 0 || !chkvnlock(bp->b_vp)) {
        bp->b_flags |= B_ERROR;
        biodone(bp);
        return (EIO);
    }
    return (VOP_STRATEGY(bp));
}

int
dead_lock(vp)
    struct vnode *vp;
{
    if (!chkvnlock(vp))
        return (0);
    return (VOP_LOCK(vp));
}

int
dead_bmap(vp, bn, vpp, bnp)
    struct vnode *vp;
    daddr_t bn;
    struct vnode **vpp;
    daddr_t *bnp;
{
    if (!chkvnlock(vp))
        return (EIO);
    return (VOP_BMAP(vp, bn, vpp, bnp));
}

int
dead_print(vp)
    struct vnode *vp;
{
    return (0);
}

int
dead_ebadf()
{
    return (EBADF);
}

int
dead_badop()
{
    kc_panic("dead_badop called");
    return (EIO);               /* not reached */
}

int
dead_nullop()
{
    return (0);
}

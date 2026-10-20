/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/vfs_vnops.c, kern/kern_descrip.c
 *   Ported from kern/vfs_vnops.c (vn_lock, vn_unlock) and kern/kern_descrip.c
 *   (flock), 4.3BSD-Reno, with two lines from 2.11BSD sys/sys_inode.c
 *   (ino_lock).  Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* kern_flock.c -- flock(2) advisory locks.
 *
 * A lock is the FILE's (FSHLOCK or FEXLOCK in f_flag) and is counted on the
 * vnode (v_shlockc, v_exlockc, and VSHLOCK/VEXLOCK/VLWAIT in v_flag), so two
 * opens of one path contend and a dup or a fork of one descriptor shares its
 * lock, as upstream's do.
 *
 * WHERE IT LIVES.  Reno keeps these beside the vnode ops in vfs_vnops.c, and
 * vfs.mod has no room left for them.  This is ufs.mod's bank, as kern_time.c
 * is, reached from the far bank through ufs_import.s: vfs_flock for the call,
 * and closef, which drops a file's lock with its last reference where 2.11BSD's
 * closef does (kern_descrip.c:359).  2.11BSD keeps the same state on the inode
 * (ino_lock, sys_inode.c); the code touches only the vnode, so any filesystem's
 * file can be locked.
 */

#include "fsparam.h"
#include "vnode.h"
#include "file.h"

extern int  kc_sleepi();      /* interruptible: 1 = a signal ended it */
extern void kc_wakeup();
int         vn_unlock();


/* vn_lock -- place a flock(2) advisory lock on a file's vnode.
 * 4.3BSD-Reno kern/vfs_vnops.c:381.
 *
 * TWO LINES ARE 2.11BSD's, because Reno's are wrong.  Reno writes the wait for
 * shared locks as `if (error = 0 && (cmd & LOCK_EX) && ...)', which assigns 0
 * and so never waits -- an exclusive lock was granted over shared ones -- and
 * ends it with `if (error = tsleep(...) == 0) return (error)', which returns
 * after a sleep that SUCCEEDED.  2.11BSD's ino_lock has the same function with
 * both right: the test is a test, and a woken sleeper goes round again.  The
 * shape and the sleep channels are Reno's.
 *
 * The sleep is interruptible, upstream's PCATCH: a signal ends the wait with
 * EINTR.
 */
int
vn_lock(fp, cmd)
register struct file *fp;
int cmd;
{
    register struct vnode *vp = (struct vnode *)fp->f_data;

again:
    while (vp->v_flag & VEXLOCK) {
        /* If we're holding an exclusive lock, then release it. */
        if (fp->f_flag & FEXLOCK) {
            vn_unlock(fp, FEXLOCK);
            continue;
        }
        if (cmd & LOCK_NB)
            return (EWOULDBLOCK);
        vp->v_flag |= VLWAIT;
        if (kc_sleepi((char *)&vp->v_exlockc))
            return (EINTR);
    }
    if ((cmd & LOCK_EX) && (vp->v_flag & VSHLOCK)) {
        /* Must wait for any shared locks to finish before we try to apply
         * an exclusive lock.  If we're holding a shared lock, then release
         * it. */
        if (fp->f_flag & FSHLOCK) {
            vn_unlock(fp, FSHLOCK);
            goto again;
        }
        if (cmd & LOCK_NB)
            return (EWOULDBLOCK);
        vp->v_flag |= VLWAIT;
        if (kc_sleepi((char *)&vp->v_shlockc))
            return (EINTR);
        goto again;
    }
    if (cmd & LOCK_EX) {
        cmd &= ~LOCK_SH;
        vp->v_exlockc++;
        vp->v_flag |= VEXLOCK;
        fp->f_flag |= FEXLOCK;
    }
    if ((cmd & LOCK_SH) && (fp->f_flag & FSHLOCK) == 0) {
        vp->v_shlockc++;
        vp->v_flag |= VSHLOCK;
        fp->f_flag |= FSHLOCK;
    }
    return (0);
}


/* vn_unlock -- drop a file's flock(2) lock.  4.3BSD-Reno kern/vfs_vnops.c:454,
 * less its two panics on a vnode whose flag disagrees with the file's, which
 * 2.11BSD's ino_unlock does not have either.
 */
int
vn_unlock(fp, kind)
register struct file *fp;
int kind;
{
    register struct vnode *vp = (struct vnode *)fp->f_data;
    int flags;

    kind &= fp->f_flag;
    if (vp == (struct vnode *)0 || kind == 0)
        return (0);
    flags = vp->v_flag;
    if (kind & FSHLOCK) {
        if (--vp->v_shlockc == 0) {
            vp->v_flag &= ~VSHLOCK;
            if (flags & VLWAIT)
                kc_wakeup((char *)&vp->v_shlockc);
        }
        fp->f_flag &= ~FSHLOCK;
    }
    if (kind & FEXLOCK) {
        if (--vp->v_exlockc == 0) {
            vp->v_flag &= ~(VEXLOCK|VLWAIT);
            if (flags & VLWAIT)
                kc_wakeup((char *)&vp->v_exlockc);
        }
        fp->f_flag &= ~FEXLOCK;
    }
    return (0);
}


/* vn_flock -- flock(2) on a vnode file.  4.3BSD-Reno kern/kern_descrip.c:418
 * from its `LOCK_UN' test on; the descriptor lookup and the DTYPE_VNODE test
 * before it are the far bank's vfs_flock, where the descriptor table is.
 */
int
vn_flock(fp, how)
register struct file *fp;
int how;
{
    if (how & LOCK_UN) {
        vn_unlock(fp, FSHLOCK|FEXLOCK);
        return (0);
    }
    if ((how & (LOCK_SH | LOCK_EX)) == 0)
        return (0);                         /* error? */
    if (how & LOCK_EX)
        how &= ~LOCK_SH;
    /* avoid work... */
    if ((fp->f_flag & FEXLOCK) && (how & LOCK_EX) ||
        (fp->f_flag & FSHLOCK) && (how & LOCK_SH))
        return (0);
    return (vn_lock(fp, how));
}

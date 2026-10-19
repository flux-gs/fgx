/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/sys/kern_sysctl.c
 *   Ported from usr/sys/sys/kern_sysctl.c, 2.11BSD.  Original work:
 *   Copyright (c) 1982, 1986, 1989, 1993 The Regents of the University of California.
 *   All rights reserved.
 */
/* root_sysctl.c -- sysctl(2), carrying one leaf.  apple/fgx#410.
 *
 * FGX-Origin: ported from 2.11BSD usr/sys/sys/kern_sysctl.c (__sysctl and
 * kern_sysctl), which its own patch #219 records as "sysctl() was borrowed
 * from 4.4BSD-Lite".  4.3BSD-Reno, which this tree's VFS ports from, has no
 * sysctl and no securelevel anywhere in the distribution.  See
 * docs/PROVENANCE.md.
 *
 *----------------------------------------------------------------------------
 * ONE LEAF, AND EVERY OTHER NAME ANSWERS ENOTSUP.
 *
 * Upstream's kern_sysctl serves twenty-four CTL_KERN ids and __sysctl
 * dispatches six top-level ones.  What this carries is CTL_KERN /
 * KERN_SECURELVL, because that is the leaf securelevel needs to be settable
 * through and the rest have no caller on FGX yet.  The NAMESPACE IS STILL THE
 * KERNEL'S: libc marshals and copies bytes, and every decision about which
 * name exists, who may write it and how big it is, is made here.  A libc that
 * knew the answer would have to be reissued to add a leaf.
 *
 *----------------------------------------------------------------------------
 * THE ARGUMENT BLOCK, and why there is one.
 *
 * sysctl(2) takes six arguments and the FGX syscall ABI carries three
 * registers, so the call arrives as a pointer to a block of words in the
 * CALLER's bank -- select(2) reaches the kernel the same way and for the same
 * reason (toolchain/lib/libc_c/select.c).  libc owns the marshalling; this
 * file owns what the words mean:
 *
 *      [0] name[0]     the top-level id
 *      [1] name[1]     the second-level id
 *      [2] namelen     how many components the caller passed
 *      [3] flags       SYSCTL_OLDP | SYSCTL_NEWP -- which pointers were given
 *      [4] oldlen      in: the caller's *oldlenp;  out: the leaf's size
 *      [5] newlen      in: the caller's newlen, when SYSCTL_NEWP
 *      [6] value       in: the new value, when SYSCTL_NEWP;  out: the old one
 *      [7..9] the rest of a value longer than 2 bytes: the long
 *                  machdep.adjkerntz, the 8-byte structs kern.clockrate and
 *                  kern.boottime
 *      [10] oldp, [11] its bank -- for a value too big for words 6..9
 *
 * flags bit SYSCTL_COPIED ($0004) comes back set when the kernel wrote the
 * value to oldp itself: the vm node's structures, served in the core bank
 * (_Sys_VmSysctl), go there because they do not fit eight bytes.
 *
 * THE VALUE TRAVELS IN THE BLOCK rather than through the caller's own oldp and
 * newp.  Those are two more far pointers this bank would have to build from a
 * bank byte and an offset, and the leaves are ints, one long and one small
 * struct -- so libc copies the value in and out as bytes, up to 8, and the
 * SIZE POLICY stays with each leaf: sysctl_int's two tests below, and
 * tod_sysctl's for machdep and for kern.clockrate, which the core routes to
 * the tty bank because the clock's rate is there.
 */

#include "../vfs/fsparam.h"

/* MIRRORED IN toolchain/include/sys/sysctl.h, which is what userland compiles
 * against; both are 2.11BSD usr/sys/h/sysctl.h's numbers.  Three constants
 * rather than a shared header because a kernel header is not on the userland
 * include path, and every syscall number in this tree is stated twice for the
 * same reason. */
#define CTL_MAXNAME     12      /* largest number of components supported */
#define CTL_KERN         1      /* "high kernel": proc, limits */
#define KERN_SECURELVL   9      /* int: system security level */

/* ...and the flag words libc sets, which stand in for upstream's test of
 * `uap->old != NULL' and `uap->new != NULL'. */
#define SYSCTL_OLDP     0x0001
#define SYSCTL_NEWP     0x0002

/* vfs.mod, through vfs_import.s.  The variable lives beside spec_open's gate,
 * which is the reader on the hot path; this is the rare direction. */
extern int vfs_getsecurelevel();
extern int vfs_setsecurelevel();


/* root_sysctl -- the whole of sysctl(2).
 *
 * `pid' and `uid' are the CALLER's, supplied by the core-bank stub because
 * that is where a credential can be read.  Upstream takes them from `u.'
 * directly -- `suser()' at kern_sysctl.c:100 and `u.u_procp->p_pid' at :233 --
 * and this bank has no u-area to read.
 *
 * Out: 0, or the errno.  The block is updated in place, in the caller's bank.
 */
int
root_sysctl(pid, uid, blk)
int  pid;
int  uid;
int *blk;
{
    int flags, namelen, level, newval;

    flags   = blk[3];
    namelen = blk[2];

    /* THE ORDER IS UPSTREAM'S, and the first test is the interesting one:
     *
     *      if (uap->new != NULL && !suser())
     *              return (u.u_error);
     *
     * A WRITE NEEDS ROOT, which the work item's scope paragraph had as "the
     * level may be RAISED by anyone"; reading kern_sysctl.c says otherwise and
     * the code follows the source.  Raising is the safe direction, but an
     * unprivileged raise would still lock root out of repairing a filesystem
     * until the machine reboots, which is a denial the superuser did not
     * choose. */
    if ((flags & SYSCTL_NEWP) && uid != 0)
        return (EPERM);
    /*   if (uap->namelen > CTL_MAXNAME || uap->namelen < 2)
     *           return (u.u_error = EINVAL);
     * -- "all top-level sysctl names are non-terminal", so two components is
     * the shortest name that can name anything. */
    if (namelen > CTL_MAXNAME || namelen < 2)
        return (EINVAL);
    /* __sysctl's `default:' arm, and kern_sysctl's "all sysctl names at this
     * level are terminal" (:192) folded into it -- with one leaf there is no
     * node below CTL_KERN for a third component to mean anything in. */
    if (blk[0] != CTL_KERN || blk[1] != KERN_SECURELVL || namelen != 2)
        return (ENOTSUP);

    /* sysctl_int, kern_sysctl.c, which every int leaf goes through:
     *
     *      if (oldp && *oldlenp < sizeof(int))  return (ENOMEM);
     *      if (newp && newlen != sizeof(int))   return (EINVAL);
     *      *oldlenp = sizeof(int);
     *      if (oldp)  error = copyout(valp, oldp, sizeof(int));
     *      if (error == 0 && newp) error = copyin(newp, valp, sizeof(int));
     *
     * THE OLD VALUE IS PUBLISHED BEFORE THE NEW ONE IS REFUSED, which is the
     * copyout-then-copyin order above: a caller that asked for both gets the
     * reading it asked for even when the write is denied. */
    if ((flags & SYSCTL_OLDP) && blk[4] < 2)
        return (ENOMEM);
    if ((flags & SYSCTL_NEWP) && blk[5] != 2)
        return (EINVAL);
    newval = blk[6];
    level  = vfs_getsecurelevel();
    blk[4] = 2;                         /* sizeof(int) on this machine */
    blk[6] = level;

    if (flags & SYSCTL_NEWP) {
        /* kern_sysctl.c:233.  LOWERING IS PID 1's ALONE:
         *
         *      if (level < securelevel && u.u_procp->p_pid != 1)
         *              return (EPERM);
         *
         * Equal is not lower, so a re-raise to the level already in force is
         * permitted -- which is what makes init's raise idempotent across a
         * re-read of /etc/rc. */
        if (newval < level && pid != 1)
            return (EPERM);
        return (vfs_setsecurelevel(newval));
    }
    return (0);
}

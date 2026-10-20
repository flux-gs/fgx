/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* sysctl(2): six arguments into the data-bank _sysctl_argblk, because the FGX
 * syscall ABI carries three registers -- select(2) is marshalled the same way
 * and for the same reason.  The block's layout is stated once, in the kernel:
 * src/kernel/far/root_sysctl.c.  Words:
 *   [0]name[0] [1]name[1] [2]namelen [3]flags [4]oldlen [5]newlen
 *   [6..9]value (up to 8 bytes, in memory order) [10]oldp [11]its bank
 *
 * THE NAMESPACE IS NOT DECIDED HERE.  This copies bytes and hands the whole
 * name over; which names exist, who may write one and how big it is are the
 * kernel's answers.  A libc that held the table would have to be reissued to
 * add a leaf.
 *
 * A VALUE OF UP TO 8 BYTES TRAVELS IN THE BLOCK: ints, the long
 * machdep.adjkerntz, the structs kern.clockrate and kern.boottime.  A larger
 * one -- the vm node's structures -- the kernel copies to oldp itself, and
 * says so with SYSCTL_COPIED in the flags word.  The kernel owns the size
 * POLICY -- it returns ENOMEM for an `oldp' too small and EINVAL for a
 * `newlen' that is not the leaf's size, and reports the size in oldlen -- so
 * this file carries `newlen' bytes in and the reported size out, as bytes.
 * sysctl(2)'s BUGS section says so. */
#define SYSCTL_VALMAX   8
#include <sys/sysctl.h>
#include <errno.h>
#include <string.h>

/* sysctl(2)'s data-bank arg block (12 words, apple/fgx#410).  Six arguments
 * do not fit the three-register syscall ABI, so they are marshalled here and
 * the kernel reads and writes the block in place.  The layout is stated once,
 * in src/kernel/far/root_sysctl.c's header:
 *   [0]name[0] [1]name[1] [2]namelen [3]flags [4]oldlen [5]newlen
 *   [6..9]value (up to 8 bytes, in memory order) [10]oldp [11]its bank */
int _sysctl_argblk[12];

#define SYSCTL_OLDP     0x0001
#define SYSCTL_NEWP     0x0002
#define SYSCTL_COPIED   0x0004          /* out: the kernel wrote oldp */

int sysctl(name, namelen, oldp, oldlenp, newp, newlen)
int    *name;
unsigned namelen;
void   *oldp;
unsigned *oldlenp;
void   *newp;
unsigned newlen;
{
    int r, flags;

    /* `namelen < 2' is the kernel's to refuse and it does, but name[1] is read
     * unconditionally below -- so the bound that protects THIS file's own read
     * is checked here too. */
    if (namelen < 2 || namelen > CTL_MAXNAME) {
        errno = EINVAL;
        return -1;
    }

    flags = 0;
    _sysctl_argblk[4] = 0;
    _sysctl_argblk[5] = 0;
    _sysctl_argblk[6] = 0;
    _sysctl_argblk[7] = 0;
    _sysctl_argblk[8] = 0;
    _sysctl_argblk[9] = 0;
    if (newp && newlen > SYSCTL_VALMAX) {
        errno = EINVAL;
        return -1;
    }
    _sysctl_argblk[10] = 0;
    _sysctl_argblk[11] = 0;
    if (oldp) {
        flags |= SYSCTL_OLDP;
        _sysctl_argblk[4] = (int)(oldlenp ? *oldlenp : 0);
        _sysctl_argblk[10] = (int)(unsigned long)oldp;
        _sysctl_argblk[11] = (int)((unsigned long)oldp >> 16);
    }
    if (newp) {
        flags |= SYSCTL_NEWP;
        _sysctl_argblk[5] = (int)newlen;
        memcpy((char *)&_sysctl_argblk[6], newp, newlen);
    }
    _sysctl_argblk[0] = name[0];
    _sysctl_argblk[1] = name[1];
    _sysctl_argblk[2] = (int)namelen;
    _sysctl_argblk[3] = flags;

    r = (int)__syscall(117, (unsigned)(unsigned long)&_sysctl_argblk[0], 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }

    if (oldp && !(_sysctl_argblk[3] & SYSCTL_COPIED)) {
        r = _sysctl_argblk[4];
        if (r > SYSCTL_VALMAX)
            r = SYSCTL_VALMAX;
        memcpy(oldp, (char *)&_sysctl_argblk[6], r);
    }
    if (oldlenp)
        *oldlenp = (unsigned)_sysctl_argblk[4];
    return 0;
}

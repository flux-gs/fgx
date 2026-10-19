/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* FGX-Origin: original -- FGX code.  It CITES BSD but contains none of it.
 */
/* dev_mount.c -- the far bank's read/write/ioctl/select bracket.
 *
 * THE FILE NO LONGER MOUNTS ANYTHING AND KEEPS ITS NAME ON PURPOSE: the two
 * functions left are still `dev_rw' and `dev_ioctlsel', which the KFAR slot
 * comments, the seam entries and the core's tail-jumps all name, and renaming
 * a file to match two symbols would cost more reading than it saves.  What it
 * IS now is one line: a descriptor whose f_ops live in THIS bank has its
 * whole syscall crossed over rather than its arm sent back, because the
 * core's dispatch does PHA/RTS on an in-bank offset.  Every file on the
 * mounted UFS root is such a descriptor.
 *
 *----------------------------------------------------------------------------
 * WHAT LEFT, 2026-09-05, AND THE CODE NAMED ITS OWN EXPIRY.
 *
 * This file used to mount a separate /dev VOLUME at boot -- real IFCHR inodes
 * on a 2.11BSD filesystem of their own, mounted at /dev while the root was
 * still ProDOS.  Its own header said how long that would last:
 *
 *     "A kernel that mounts one named directory off a volume of its own is a
 *      ProDOS-era workaround for a filesystem with no inode to hold a device
 *      number, and it lasts exactly as long as ProDOS is a root this kernel
 *      resolves through."
 *
 * ProDOS stopped being that root on 2026-09-04, the UFS root carries its own
 * /dev, and `dev_mount' had already been reduced to
 * `if (root_status == 1) return (DEV_ROOT_HAS_DEV);' -- so on every boot this
 * tree makes, the 9,245 bytes below that line never executed.
 *
 * MEASURED BEFORE REMOVING, because "unreachable" is a claim: the boot klog
 * of tools/mame_test/tests/mountprobe.json holds 1,159 bytes of log, `vfs:
 * seam ok' among them, and NOT ONE `fs: /dev' line.  That manifest's only
 * assertion was `klog_lacks "fs: /dev SELF-TEST FAILED"', so it had been
 * passing VACUOUSLY -- the exact shape of "a check whose tool did not run
 * looks like a pass".  It and bsd211probe are retired with the code; the
 * second could not run here anyway, `disk/bsd211root.po' being absent.
 *
 * WHAT WENT WITH IT, and what replaces each:
 *   dev_mountcase   4,541 B  mount(2)'s boot self-test.  It stood in for a
 *                            syscall that did not exist; mount(2) + mount(8)
 *                            test it from userland, which is the better
 *                            instrument -- a test that runs as a user runs it.
 *   dev_bsdrootcase 1,689 B  mounted a REAL 2.11BSD root, phase 1 gate arm 4.
 *                            Same replacement: `mount /dev/sd1 /mnt; ls /mnt'.
 *   dev_lseekcase     981 B  seek arm of the same self-test.
 *   dev_mount       1,044 B  the mount, down to the decline.
 *   mp_walk           546 B  the mount-point walk.
 *   is_devvol/is_bsdrootvol/is_scratchvol  906 B  the volume sniffers.
 *   dev_vncheck + dev_nodecheck  582 B  boot self-tests of the /dev mount.
 *   dev_open          123 B  its only caller, `_Sys_DevOpen', had already lost
 *                            ITS caller when the /dev open hook was retired --
 *                            dead code reachable only from dead code.
 *
 * THE FAR BANK IS WHY, and the number is the argument: it stood at 86 bytes
 * free of 60,480 with access(2), link(2), mount(2), unmount(2) and fchdir(2)
 * still to land, each costing a KFAR slot, a seam entry and a bracket in this
 * bank.  21% of the tightest bank on the branch was boot self-tests for a
 * feature that had been retired.  KFAR slots 36 and 37 come back with them.
 *----------------------------------------------------------------------------
 */

#include "../vfs/fsparam.h"
#include "../vfs/vnode.h"
#include "../vfs/uio.h"

/* THIS BANK'S OWN, from vfs_syscalls.c -- no shim, no bank crossing. */
extern int  rwuio();
extern int  vfs_ioctl();
extern int  vfs_select();


/* dev_rw -- read(2), write(2), readv(2) or writev(2) on a descriptor whose
 * ops are in this bank: rwuio over the uio the core bank built in the task's
 * u-area (_Sys_DevUio).  The direction is the uio's uio_rw.
 *
 * THE BUFFERS ARE COMPLETE 24-BIT POINTERS.  On a 65816 there is one address
 * space and a bank is part of an address, so a user pointer is not a pointer
 * that must be TRANSLATED -- it is one that must be COMPLETE, and the core
 * completes each iov_base from the caller's bank before calling.
 *
 * THE COUNT WINS OVER THE ERRNO when both are present.  A transfer that moved
 * bytes and then failed must report the bytes: the bytes are gone from the
 * source and an errno loses them (2.11BSD rwuio's setjmp arm).
 *
 * Returns the count (>= 0), or -errno.  The two cannot collide: no errno is 0
 * and no count is negative -- the core refuses totals past 32767.
 */
int
dev_rw(pid, fd, uio)
int         pid;
int         fd;
struct uio *uio;
{
    int cnt;
    int error;

    cnt = 0;
    error = rwuio(pid, fd, uio, &cnt);
    if (cnt > 0)
        return (cnt);
    if (error)
        return (-error);
    return (0);
}


/* dev_ioctlsel -- ioctl(2) or select(2) on a descriptor whose ops are in this
 * bank.  UFS 1.7d I4.
 *
 * ONE ENTRY FOR TWO CALLS, for the reason dev_rw is one body behind two entry
 * points: what differs is a boolean, and the whole cost of crossing the seam
 * is the argument copy.  A second slot would have bought a second copy of that
 * copy.  `com' and `data' are not read when isioctl is 0 -- select has no
 * command and no argument -- and the core side pushes whatever is staged
 * rather than branching to push zeros, which costs nothing here and saves
 * bytes in the bank that has none.
 *
 * NEGATIVE IS -errno IN BOTH DIRECTIONS, which is dev_rw's convention and
 * works for the same reason: no errno is zero, and neither an ioctl's success
 * nor a three-bit readiness mask can be negative.  So one signed word carries
 * the answer and the failure without a second output.
 *
 * IOCTL SUCCESS IS 0 AND SELECT'S ANSWER IS A MASK, and the caller knows which
 * it asked for.  That is not ambiguity: a caller that asked for an ioctl and
 * got 3 back would be reading a readiness it never requested, which cannot
 * happen because isioctl is its own argument and not inferred.
 */
int
dev_ioctlsel(pid, fd, com, data, isioctl)
int   pid;
int   fd;
int   com;
char *data;
int   isioctl;
{
    int error;

    if (isioctl) {
        error = vfs_ioctl(pid, fd, com, data);
        if (error)
            return (-error);
        return (0);
    }
    /* vfs_select answers -errno itself, because its success value is a mask
     * whose zero ("ready for nothing") is a real answer and not an absence. */
    return (vfs_select(pid, fd));
}

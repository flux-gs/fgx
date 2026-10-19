/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* getmntinfo.c -- getmntinfo(3).
 *
 * FGX-Provenance: 2.11BSD lib/libc/gen/getmntinfo.c
 *   Ported from getmntinfo(3), 2.11BSD (8.1.1, 1995/12/26).  Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * A MEMBER OF ITS OWN, WHICH IS UPSTREAM'S LAYOUT AND ALSO THIS ARCHIVE'S
 * REQUIREMENT.  It was written into wait.c beside getfsstat(2), and that
 * broke the build of programs which want nothing from this file: wait.c
 * carries getpgrp(2), conctty selects it for that, and getmntinfo's `free'
 * came along as an unresolved `PEA free-1' because the dead-strip selects
 * whole members.  Upstream keeps it in lib/libc/gen/getmntinfo.c by itself;
 * so does this.  The pile's own header makes the general point -- a
 * dead-strip that drops a member breaks the COMPILE of the survivors.
 */

/* getmntinfo(3), from vendor/2.11BSD/usr/lib/libc/gen/getmntinfo.c 8.1.1
 * (2.11BSD) 1995/12/26, verbatim but for the K&R-to-prototype header.  Its
 * body is identical to 4.3BSD-Reno's (lib/libc/gen/getmntinfo.c 6.3); 2.11BSD
 * is the source per the standing port rule, and its version is the one that
 * includes <stdlib.h> -- which on this toolchain is not cosmetic, an
 * undeclared malloc being exactly apple/fgx#327.
 *
 * THE `while' IS A LOOP AND NOT AN `if' IN UPSTREAM, and it is kept that way:
 * a mount can appear between the sizing call and the filling one, and the
 * loop is what re-reads instead of truncating. */
int getmntinfo(struct statfs **mntbufp, int flags)
{
    static struct statfs *mntbuf;
    static int mntsize;
    static int bufsize;

    if (mntsize <= 0 && (mntsize = getfsstat((struct statfs *)0, 0,
                                             MNT_NOWAIT)) < 0)
        return (0);
    if (bufsize > 0 && (mntsize = getfsstat(mntbuf, bufsize, flags)) < 0)
        return (0);
    while (bufsize <= mntsize * (int)sizeof(struct statfs)) {
        if (mntbuf)
            free(mntbuf);
        bufsize = (mntsize + 1) * (int)sizeof(struct statfs);
        if ((mntbuf = (struct statfs *)malloc((unsigned long)bufsize)) == 0)
            return (0);
        if ((mntsize = getfsstat(mntbuf, bufsize, flags)) < 0)
            return (0);
    }
    *mntbufp = mntbuf;
    return (mntsize);
}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- ftime(3): the time, and the kernel's zone, in a struct timeb --------
 * FGX-Provenance: 2.11BSD lib/libc/compat-4.1/ftime.c (5.2 (Berkeley) 3/9/86)
 *   vendored at vendor/2.11BSD/usr/lib/libc/compat-4.1/ftime.c.  Copyright (c)
 *   1980 Regents of the University of California.  All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * Upstream's body, with the structure taken from <sys/timeb.h> rather than
 * redeclared here, and a 0 return on success where upstream fell off the end.
 * The zone is the KERNEL's (tz_minuteswest, tz_dsttime), which settimeofday(2)
 * sets and which is 0 at boot, as in 2.11BSD without a configured TIMEZONE --
 * not /etc/localtime's.  ac(8) is the caller.
 */
int ftime(tp)
    register struct timeb *tp;
{
    struct timeval t;
    struct timezone tz;

    if (gettimeofday(&t, &tz) < 0)
        return (-1);
    tp->time = t.tv_sec;
    tp->millitm = t.tv_usec / 1000;
    tp->timezone = tz.tz_minuteswest;
    tp->dstflag = tz.tz_dsttime;
    return (0);
}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* FGX libc -- sys/timeb.h.
 *
 * FGX-Provenance: 2.11BSD sys/h/timeb.h (7.1 (Berkeley) 6/4/86), vendored at
 *   vendor/2.11BSD/usr/sys/h/timeb.h.  Copyright (c) 1982, 1986
 *   Regents of the University of California.  All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see docs/PROVENANCE.md).
 *
 * The structure ftime(3) fills from gettimeofday(2), timezone in minutes west
 * and dstflag as the kernel keeps them; ftime's declaration is added.
 */
#ifndef _SYS_TIMEB_H
#define _SYS_TIMEB_H

struct timeb
{
	long	time;
	unsigned short millitm;
	short	timezone;
	short	dstflag;
};

int ftime(struct timeb *tp);

#endif

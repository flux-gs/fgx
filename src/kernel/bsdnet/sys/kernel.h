/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/kernel.h
 *   Ported from usr/sys/h/kernel.h, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/*
 * Copyright (c) 1986 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 *
 *	@(#)kernel.h	1.3 (2.11BSD GTE) 1997/2/14
 */

/*
 * Global variables for the kernel
 */

#ifdef SUPERVISOR
long	startnet;			/* start of network data space */
#else
memaddr	malloc();

/* 1.1 */
long	hostid;
char	hostname[MAXHOSTNAMELEN];
int	hostnamelen;

/* 1.2 */
#include <sys/time.h>

struct	timeval boottime;
struct	timeval time;
struct	timezone tz;			/* XXX */
int	adjdelta;
int	hz;
int	mshz;				/* # milliseconds per hz */
int	lbolt;				/* awoken once a second */
int	realitexpire();

short	avenrun[3];
#endif

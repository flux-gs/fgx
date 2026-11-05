/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/pdp/net_trap.s
 *   Written for FGX after usr/sys/pdp/net_trap.s, 2.11BSD.  Original work:
 *   Copyright (c) 1988 Regents of the University of California.
 *   All rights reserved.
 */
/* net_intr.c -- netintr, net_trap.s's loop in C.  It runs from the kernel's
 * deferred-work drain and must not sleep, as a software interrupt must not. */
#include "param.h"
#include "../net/netisr.h"

extern int ipintr(), rawintr();
extern void net_softclock();

int net_in_intr;	/* nonzero while netintr runs; net_asm.s sets it */

#ifdef NETPROBE
int (*np_hook)();
int np_entries;
#endif

int
netintr()
{
	register int bits;
	int s;

#ifdef NETPROBE
	np_entries++;
#endif
	net_softclock();
	do {
		s = splhigh();
		bits = netisr;
		netisr = 0;
		splx(s);
#ifdef NETPROBE
		if (np_hook)
			(*np_hook)(bits);
#endif
		if (bits & (1 << NETISR_IP))
			ipintr();
		if (bits & (1 << NETISR_RAW))	/* last: the others schedule it */
			rawintr();
	} while (netisr);
	return (0);
}

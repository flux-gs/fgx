/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/sys/kern_clock.c
 *   Written for FGX after timeout, untimeout, softclock and hardclock's queue
 *   walk in usr/sys/sys/kern_clock.c, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* net_callout.c -- 2.11BSD's callout list, private to the network modules.  It
 * has no clock interrupt: net_softclock runs first in netintr and net_charge
 * takes the ticks that have passed, charging them as hardclock charges one.  Only code at task level or in netintr touches the list, and
 * neither can interrupt the other, so nothing here raises the spl. */
#include "param.h"

/* pfslowtimo, pffasttimo, if_slowtimo, arptimer, with room for the driver and
 * for what S3 arms. */
#define	NCALLOUT	20

struct	callout {
	int	c_time;		/* ticks after the one before it */
	caddr_t	c_arg;
	int	(*c_func)();
	struct	callout *c_next;
};

extern	int kc_ticks();
extern	void panic();

static	struct callout net_callouts[NCALLOUT];
static	struct callout *callfree, calltodo;
static	long net_lastticks;

#ifdef NETPROBE
extern	int pfslowtimo();
int	np_slowruns;
#endif

void
net_calloutinit()
{
	register int i;

	for (i = 1; i < NCALLOUT; i++)
		net_callouts[i - 1].c_next = &net_callouts[i];
	callfree = &net_callouts[0];
	kc_ticks(&net_lastticks);
}

/* Charge the ticks since the last charge to the list.  Upstream's hardclock does
 * this for each tick; here it also has to happen before an insertion, or the new
 * entry would be charged for time before it was armed. */
static void
net_charge()
{
	static long now;
	register struct callout *p1;
	register int d, t;

	kc_ticks(&now);
	if (now - net_lastticks > 30000L)
		d = 30000;
	else
		d = (int)(now - net_lastticks);
	net_lastticks = now;
	for (p1 = calltodo.c_next; p1 != 0 && d > 0; p1 = p1->c_next) {
		t = p1->c_time;
		p1->c_time = t - d;
		if (t > d)
			break;
		if (t > 0)
			d -= t;
	}
}

/* Arrange that (*fun)(arg) is called in t/hz seconds. */
void
timeout(fun, arg, t)
	int (*fun)();
	caddr_t arg;
	register int t;
{
	register struct callout *p1, *p2, *pnew;

	net_charge();
	if (t <= 0)
		t = 1;
	pnew = callfree;
	if (pnew == 0)
		panic("timeout table overflow");
	callfree = pnew->c_next;
	pnew->c_arg = arg;
	pnew->c_func = fun;
	for (p1 = &calltodo; (p2 = p1->c_next) != 0 && p2->c_time < t; p1 = p2)
		if (p2->c_time > 0)
			t -= p2->c_time;
	p1->c_next = pnew;
	pnew->c_next = p2;
	pnew->c_time = t;
	if (p2)
		p2->c_time -= t;
}

/* Remove a pending call. */
void
untimeout(fun, arg)
	int (*fun)();
	caddr_t arg;
{
	register struct callout *p1, *p2;

	for (p1 = &calltodo; (p2 = p1->c_next) != 0; p1 = p2) {
		if (p2->c_func == fun && p2->c_arg == arg) {
			if (p2->c_next && p2->c_time > 0)
				p2->c_next->c_time += p2->c_time;
			p1->c_next = p2->c_next;
			p2->c_next = callfree;
			callfree = p2;
			break;
		}
	}
}

/* Run what is due.  An element's negative c_time is how late it is, the second
 * argument it gets, as in upstream. */
void
net_softclock()
{
	register struct callout *p1;
	register int t;
	caddr_t arg;
	int (*func)();

	net_charge();
	while ((p1 = calltodo.c_next) != 0 && p1->c_time <= 0) {
		arg = p1->c_arg;
		func = p1->c_func;
		t = p1->c_time;
		calltodo.c_next = p1->c_next;
		p1->c_next = callfree;
		callfree = p1;
#ifdef NETPROBE
		if (func == pfslowtimo)
			np_slowruns++;
#endif
		(*func)(arg, t);
	}
}

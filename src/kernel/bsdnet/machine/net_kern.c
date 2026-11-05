/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/pdp/net_copy.s
 *   Written for FGX after 2.11BSD's PDP-11 assembly.  Original work:
 *   Copyright (c) 1988 Regents of the University of California.
 *   All rights reserved.
 */
/* net_kern.c -- the kernel routines the network code expects, on FGX. */
#include "param.h"
#include "user.h"
#include "time.h"

extern	int kc_sleep(), kc_sleepi(), kc_wakeup(), kc_panic();
extern	long kc_time();
extern	int kc_ticks();
extern	int net_in_intr;

struct	user u;
int	hz = 60;
struct	timeval time;
int	lbolt;		/* mfkd() answers for it; see there */

/* ponytail: C byte loops, as tty_dev.c has.  Replace them when a profile of a
 * transfer says to; the fused receive copy is the driver's, not this. */
void
bzero(cp, n)
	register char *cp;
	register int n;
{
	while (--n >= 0)
		*cp++ = 0;
}

void
bcopy(from, to, n)
	register char *from, *to;
	register int n;
{
	while (--n >= 0)
		*to++ = *from++;
}

int
bcmp(a, b, n)
	register char *a, *b;
	register int n;
{
	while (--n >= 0)
		if (*a++ != *b++)
			return (1);
	return (0);
}

/* The queue operations a VAX has in hardware: each element starts with its
 * forward and back pointers. */
struct qelem {
	struct	qelem *q_next;
	struct	qelem *q_prev;
};

void
insque(e, pred)
	register struct qelem *e, *pred;
{
	e->q_next = pred->q_next;
	e->q_prev = pred;
	pred->q_next->q_prev = e;
	pred->q_next = e;
}

void
remque(e)
	register struct qelem *e;
{
	e->q_next->q_prev = e->q_prev;
	e->q_prev->q_next = e->q_next;
}

void
panic(s)
	char *s;
{
	kc_panic(s);
}

/* ponytail: the format string, without its arguments.  Enough to name what
 * happened; widen it when a message's numbers are needed. */
int
printf(s)
	char *s;
{
	kc_printstr(s);
	return (0);
}

/* A pri above PZERO may be interrupted, as in 2.11BSD's sleep().  Returning from
 * an interrupted one is the same return: every caller re-tests its condition. */
void
sleep(chan, pri)
	caddr_t chan;
	int pri;
{
	if (net_in_intr)
		panic("sleep in netintr");
	if ((pri & PRIMASK) > PZERO)
		(void) kc_sleepi(chan);
	else
		(void) kc_sleep(chan);
}

void
wakeup(chan)
	caddr_t chan;
{
	kc_wakeup(chan);
}

int
suser()
{
	return (u.u_uid == 0);
}

/* The PDP-11's copies between kernel and supervisor space read kernel variables
 * here, and these are the only two the network code asks for. */
int
mfkd(addr)
	int *addr;
{
	static long ticks;

	if (addr == &lbolt) {
		kc_ticks(&ticks);
		return ((int)ticks);
	}
	return (*addr);
}

void
cpfromkern(from, to, n)
	char *from, *to;
	int n;
{
	if (from == (char *)&time)
		time.tv_sec = kc_time();
	bcopy(from, to, n);
}

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
extern	int kc_ticks(), kc_curpid();
extern	int net_in_intr;

struct	user u;
int	hz = 60;
struct	timeval time;
int	lbolt;		/* mfkd() answers for it; see there */

/* bcopy is net_asm.s's, as 2.11BSD's is assembly (libc pdp/gen/bcopy.s).
 * ponytail: bzero and bcmp stay C byte loops; a transfer's profile puts them
 * under 1%. */
void
bzero(cp, n)
	register char *cp;
	register int n;
{
	while (--n >= 0)
		*cp++ = 0;
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

/* 2.11BSD's printf, prf and printn (sys/subr_prf.c), to the log a line at a
 * time through kc_printstr, which ends each line itself: a newline flushes
 * the line, and so does the end of a message without one.  The arguments are
 * walked as upstream walks them, from the first one's address; a pointer is
 * two ints here, so %s steps over both.  %b and the tty argument are left
 * out: nothing in the stack prints a bit field or to a terminal. */
static	char prline[81];
static	int prlen;

static void
prputc(c)
	int c;
{
	if (c != '\n')
		prline[prlen++] = c;
	if (c == '\n' || prlen == sizeof(prline) - 1) {
		prline[prlen] = '\0';
		kc_printstr(prline);
		prlen = 0;
	}
}

static void
printn(n, b)
	long n;
	u_int b;
{
	char prbuf[12];
	register char *cp = prbuf;
	register int offset = 0;

	if (n<0)
		switch(b) {
		case 8:		/* unchecked, but should be like hex case */
		case 16:
			offset = b-1;
			n++;
			break;
		case 10:
			prputc('-');
			n = -n;
			break;
		}
	do {
		*cp++ = "0123456789ABCDEF"[offset + n%b];
	} while (n = n/b);	/* Avoid  n /= b, since that requires alrem */
	do
		prputc(*--cp);
	while (cp > prbuf);
}

static void
prf(fmt, adx)
	register char *fmt;
	register u_int *adx;
{
	register int c;
	u_int b;
	char *s;

loop:
	while ((c = *fmt++) != '%') {
		if (c == '\0')
			return;
		prputc(c);
	}
	c = *fmt++;
	switch (c) {

	case 'l':
		c = *fmt++;
		switch(c) {
			case 'x':
				b = 16;
				goto lnumber;
			case 'd':
				b = 10;
				goto lnumber;
			case 'o':
				b = 8;
				goto lnumber;
			default:
				prputc('%');
				prputc('l');
				prputc(c);
		}
		break;
	case 'X':
		b = 16;
		goto lnumber;
	case 'D':
		b = 10;
		goto lnumber;
	case 'O':
		b = 8;
lnumber:	printn(*(long *)adx, b);
		adx += (sizeof(long) / sizeof(int)) - 1;
		break;
	case 'x':
		b = 16;	
		goto number;
	case 'd':
	case 'u':		/* what a joke */
		b = 10;
		goto number;
	case 'o':
		b = 8;
number:		printn((long)*adx, b);
		break;
	case 'c':
		prputc(*adx);
		break;
	case 's':
		s = *(char **)adx;
		adx += (sizeof(char *) / sizeof(int)) - 1;
		while (c = *s++)
			prputc(c);
		break;
	case '%':
		prputc(c);
		break;
	default:
		prputc('%');
		prputc(c);
		break;
	}
	adx++;
	goto loop;
}

int
printf(fmt, x1)
	char *fmt;
	unsigned x1;
{
	prf(fmt, &x1);
	if (prlen)
		prputc('\n');
	return (0);
}

/* 2.11BSD's sleep() (sys/kern_synch.c): a pri above PZERO may be interrupted,
 * and then u_error is EINTR and the call longjmps to u.u_qsave, where the socket
 * call's setjmp arm returns it.  An ordinary wakeup leaves u_error 0, as
 * upstream's `u.u_error = tsleep(...)' does.  u is one global, so the caller's
 * copy is kept across the sleep in its process's slot: another process's socket
 * call may fill u in the meantime.  A slot rather than a local, because sleep is
 * at the bottom of the deepest socket call and the stack has no room for it. */
#define	USAVE	((char *)&u.u_ofile[0] - (char *)&u)
static	char u_saved[NPROC + 1][sizeof(struct user) - NOFILE * sizeof(struct file *)];

void
sleep(chan, pri)
	caddr_t chan;
	int pri;
{
	register int pid;
	int intr;

	if (net_in_intr)
		panic("sleep in netintr");
	pid = kc_curpid();
	if (pid < 0 || pid > NPROC)
		panic("sleep: pid");
	bcopy((char *)&u, u_saved[pid], USAVE);
	if ((pri & PRIMASK) > PZERO)
		intr = kc_sleepi(chan);
	else {
		(void) kc_sleepr(chan);
		intr = 0;
	}
	bcopy(u_saved[pid], (char *)&u, USAVE);
	u.u_error = intr ? EINTR : 0;
	if (intr)
		longjmp(&u.u_qsave, 1);
}

void
wakeup(chan)
	caddr_t chan;
{
	kc_wakeup(chan);
}

/* 2.11BSD sys/sys_net.c: a refusal is EPERM in u_error, which in_control
 * returns. */
int
suser()
{
	if (u.u_uid == 0)
		return (1);
	u.u_error = EPERM;
	return (0);
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

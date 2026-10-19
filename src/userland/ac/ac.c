/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD ac(8)
 *   Ported from ac(8), 2.11BSD (ac.c 4.7.1 (2.11BSD) 1996/11/16,
 *   vendor/2.11BSD/usr/usr.sbin/ac/ac.c).
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* ac - connect-time accounting from /etc/wtmp.
 *
 * THE BODY IS 2.11BSD's; the argument parse, the wtmp read loop, the per-tty
 * tbuf/per-user ubuf pairing, upall()/update()/among()/loop(), and the `-d'
 * (by day), `-p' (per person) and `-w file' options are upstream's.  The
 * default log is already _PATH_WTMP through <utmp.h>, so unlike last(1) even
 * that needed no edit.  One FGX delta, marked FGX: ctime() is prototyped (via
 * <time.h>) rather than left implicit, because it returns a 24-bit pointer
 * whose bank an assumed-int return would drop on fcc -- the same far-return
 * trap last(1) carries.
 *
 * Day boundaries are upstream's: newday() takes the zone from ftime(3), which
 * is the KERNEL's tz_minuteswest (0 unless settimeofday(2) sets it), corrected
 * by the local tm_isdst -- not /etc/localtime's offset.
 *
 * The tty index (loop(): line[3]/line[4] hashed into tbuf) is upstream's,
 * unchanged (`i = (ut_line[3]-'0'); if (ut_line[4]) i = i*79 + (ut_line[4]-'0');',
 * vendor/2.11BSD/usr/usr.sbin/ac/ac.c:150-153).  FGX writes six line names
 * (init.c from /etc/ttys; login.c): console takes the non-tty branch (i =
 * TSIZE-1 = 6241); ttyp0, ttyp1, ttyv1, ttyv2 and ttyv3 take the tty branch
 * and index 5,056, 5,057 and 5,531-5,533.  All six land inside TSIZE (6242),
 * so nothing collides and the "Bad tty name" arm never fires.
 */
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>            /* exit */
#include <time.h>             /* ctime: 24-bit return, must be prototyped */
#include <sys/timeb.h>
#include <utmp.h>

#define NMAX sizeof(ibuf.ut_name)
#define LMAX sizeof(ibuf.ut_line)

/*
#define	TSIZE	1000
*/
#define TSIZE  6242
#define	USIZE	500
struct  utmp ibuf;

struct ubuf {
	char	uname[NMAX];
	long	utime;
} ubuf[USIZE];

struct tbuf {
	struct	ubuf	*userp;
	long	ttime;
} tbuf[TSIZE];

char	*wtmp;
int	pflag, byday;
long	dtime;
long	midnight;
long	lastime;
long	day	= 86400L;
int	pcount;
char	**pptr;

main(argc, argv)
char **argv;
{
	int c, fl;
	register i;
	FILE *wf;

	wtmp = _PATH_WTMP;
	while (--argc > 0 && **++argv == '-')
	switch(*++*argv) {
	case 'd':
		byday++;
		continue;
	case 'f':
	case 'w':
		if (--argc>0)
			wtmp = *++argv;
		continue;

	case 'p':
		pflag++;
		continue;
	}
	pcount = argc;
	pptr = argv;
	if ((wf = fopen(wtmp, "r")) == NULL) {
		printf("No %s\n", wtmp);
		exit(1);
	}
	for(;;) {
		if (fread((char *)&ibuf, sizeof(ibuf), 1, wf) != 1)
			break;
		fl = 0;
		for (i=0; i<NMAX; i++) {
			c = ibuf.ut_name[i];
			if (isprint(c) && c != ' ') {
				if (fl)
					goto skip;
				continue;
			}
			if (c==' ' || c=='\0') {
				fl++;
				ibuf.ut_name[i] = '\0';
			} else
				goto skip;
		}
		loop();
	    skip:;
	}
	ibuf.ut_name[0] = '\0';
	ibuf.ut_line[0] = '~';
	time(&ibuf.ut_time);
	loop();
	print();
	exit(0);
}

loop()
{
	register i;
	register struct tbuf *tp;
	register struct ubuf *up;

	if(ibuf.ut_line[0] == '|') {
		dtime = ibuf.ut_time;
		return;
	}
	if(ibuf.ut_line[0] == '{') {
		if(dtime == 0)
			return;
		for(tp = tbuf; tp < &tbuf[TSIZE]; tp++)
			tp->ttime += ibuf.ut_time-dtime;
		dtime = 0;
		return;
	}
	if (lastime>ibuf.ut_time || lastime+(1.5*day)<ibuf.ut_time)
		midnight = 0;
	if (midnight==0)
		newday();
	lastime = ibuf.ut_time;
	if (byday && ibuf.ut_time > midnight) {
		upall(1);
		print();
		newday();
		for (up=ubuf; up < &ubuf[USIZE]; up++)
			up->utime = 0;
	}
	if (ibuf.ut_line[0] == '~') {
		ibuf.ut_name[0] = '\0';
		upall(0);
		return;
	}
	/*
	if (ibuf.ut_line[0]=='t')
		i = (ibuf.ut_line[3]-'0')*10 + (ibuf.ut_line[4]-'0');
	else
		i = TSIZE-1;
	if (i<0 || i>=TSIZE)
		i = TSIZE-1;
	*/

	/*
	 * Correction contributed by Phyllis Kantar @ Rand-unix
	 *
	 * Fixes long standing problem with tty names other than 00-99
	 */
	if (ibuf.ut_line[0]=='t') {
		i = (ibuf.ut_line[3]-'0');
		if(ibuf.ut_line[4])
			i = i*79 + (ibuf.ut_line[4]-'0');
	} else
		i = TSIZE-1;
	if (i<0 || i>=TSIZE) {
		i = TSIZE-1;
		printf("ac: Bad tty name: %s\n", ibuf.ut_line);
	}

	tp = &tbuf[i];
	update(tp, 0);
}

print()
{
	int i;
	long ttime, t;

	ttime = 0;
	for (i=0; i<USIZE; i++) {
		if(!among(i))
			continue;
		t = ubuf[i].utime;
		if (t>0)
			ttime += t;
		if (pflag && ubuf[i].utime > 0) {
			printf("\t%-*.*s%6.2f\n", NMAX, NMAX,
			    ubuf[i].uname, ubuf[i].utime/3600.);
		}
	}
	if (ttime > 0) {
		pdate();
		printf("\ttotal%9.2f\n", ttime/3600.);
	}
}

upall(f)
{
	register struct tbuf *tp;

	for (tp=tbuf; tp < &tbuf[TSIZE]; tp++)
		update(tp, f);
}

update(tp, f)
struct tbuf *tp;
{
	int j;
	struct ubuf *up;
	long t, t1;

	if (f)
		t = midnight;
	else
		t = ibuf.ut_time;
	if (tp->userp) {
		t1 = t - tp->ttime;
		if (t1 > 0)
			tp->userp->utime += t1;
	}
	tp->ttime = t;
	if (f)
		return;
	if (ibuf.ut_name[0]=='\0') {
		tp->userp = 0;
		return;
	}
	for (up=ubuf; up < &ubuf[USIZE]; up++) {
		if (up->uname[0] == '\0')
			break;
		for (j=0; j<NMAX && up->uname[j]==ibuf.ut_name[j]; j++);
		if (j>=NMAX)
			break;
	}
	for (j=0; j<NMAX; j++)
		up->uname[j] = ibuf.ut_name[j];
	tp->userp = up;
}

among(i)
{
	register j, k;
	register char *p;

	if (pcount==0)
		return(1);
	for (j=0; j<pcount; j++) {
		p = pptr[j];
		for (k=0; k<NMAX; k++) {
			if (*p == ubuf[i].uname[k]) {
				if (*p++ == '\0' || k == NMAX-1)
					return(1);
			} else
				break;
		}
	}
	return(0);
}

newday()
{
	long ttime;
	struct timeb tb;
	struct tm *localtime();

	time(&ttime);
	if (midnight == 0) {
		ftime(&tb);
		midnight = 60*(long)tb.timezone;
		if (localtime(&ttime)->tm_isdst)
			midnight -= 3600;
	}
	while (midnight <= ibuf.ut_time)
		midnight += day;
}

pdate()
{
	long x;

	if (byday==0)
		return;
	x = midnight-1;
	printf("%.6s", ctime(&x)+4);
}

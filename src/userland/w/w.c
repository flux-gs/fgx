/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD w(1)
 *   Ported from w(1), 2.11BSD (w.c 2.0 1996/11/17,
 *   vendor/2.11BSD/usr/ucb/w.c; by Mark Horton, UCB).
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* w - who is on the system and what they are doing.
 *
 * uptime(1) IS THIS BINARY under its other name, which is how 2.11BSD ships it:
 * `ln ${DESTDIR}/usr/ucb/w ${DESTDIR}/usr/ucb/uptime' (usr/ucb/Makefile:63,
 * the same idiom as f -> finger).  main() reads argv[0] and drops to the
 * header-only form when the name begins with `u', exactly as upstream does;
 * -u and -w force it either way.  /bin/uptime is a hard link to /bin/w on the
 * volume, as upstream's is: one inode, two names, link count 2.
 *
 * WHAT THE PROC HALF BECOMES.  Upstream's readpr() opens /dev/mem and
 * /dev/swap, pulls the proc table with sysctl(KERN_PROC), reads every u-area
 * and digs the argument list out of each user stack -- getargs(), getptr(),
 * getbyte(), within() and round() exist for nothing else.  procs(2) hands over
 * one fixed record per task, so readpr() is a single call and those five
 * routines have no counterpart.  The per-terminal scan compares tty NAMES
 * (procinfo.ttyname against utmp.ut_line) where upstream compares dev_t, so
 * gettty() goes with them: a name is what both sides have here.
 *
 * WHAT IS NOT PRINTED, AND WHY.  Three columns and one header clause are gone
 * because the numbers behind them do not exist:
 *
 *   idle   findidle() stats /dev/<line> and subtracts st_atime.  Nothing
 *          updates a device node's atime on read, so the column would be the
 *          age of the node rather than of the session.
 *   JCPU   per-process CPU time.  The TCB has no live counter for it.
 *   PCPU   the same number for the interesting process alone.
 *
 *   the load-average clause, the scheduler keeping no run-queue average.
 *   Upstream's own fallback for that case prints ", no load average
 *   information available", which on every single run is noise rather than
 *   information.
 *
 * A column of zeroes would read as "nobody has typed for 0 minutes", which is
 * a worse answer than not offering the column.  w(1)'s BUGS section says so.
 *
 * The `current process' rule keeps upstream's shape -- the highest-numbered
 * process on the terminal -- without the not-ignoring-interrupts refinement,
 * which needs a signal-state field the record does not carry.  Uptime comes
 * from ticks(2) rather than a KERN_BOOTTIME sysctl.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <utmp.h>
#include <time.h>
#include <fgx.h>

#define NMAX	UT_NAMESIZE
#define LMAX	UT_LINESIZE
#define NPR	24		/* procs() records: nproc is 12, plus pid 0 */

#define DIV60(t)	(((t)+30)/60)	/* x/60 rounded */

struct	procinfo pr[NPR];	/* data bank: procs() writes via the caller's DBR */
struct	utmp utmp;
FILE	*ut;
char	doing[PROC_NAME_MAX+1];	/* process attached to this terminal */
char	*program;
int	header = 1;		/* 0 once -h says not to print one */
int	lflag = 1;		/* long-style output */
int	nusers;			/* users logged in now */
char	*sel_user;		/* the single login selected, if any */
int	wcmd = 1;		/* running as w rather than as uptime */
long	now;			/* the current time of day */
struct	tm *nowt;		/* the same, as a time struct */
long	uptime;			/* elapsed time since boot */
int	np;			/* processes currently active */

int	prttime(), prtat(), readpr(), putline();

int
main(argc, argv)
	int argc;
	char **argv;
{
	int days, hrs, mins;
	int i, curpid;
	char *cp;

	program = argv[0];
	if ((cp = strrchr(program, '/')) != (char *)0 || *(cp = program) == '-')
		cp++;
	if (*cp == 'u')
		wcmd = 0;

	while ((i = getopt(argc, argv, "hlswu")) != EOF) {
		switch (i) {
		case 'h':
			header = 0;
			break;
		case 'l':
			lflag++;
			break;
		case 's':
			lflag = 0;
			break;
		case 'u':
			wcmd = 0;
			break;
		case 'w':
			wcmd = 1;
			break;
		default:
			fprintf(stderr, "Usage: %s [-hlswu] [user]\n", program);
			exit(1);
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 0)
		sel_user = argv[0];

	if (wcmd)
		readpr();

	ut = fopen(_PATH_UTMP, "r");
	if (header) {
		/* Print time of day */
		now = time((long *)0);
		nowt = localtime(&now);
		prtat(nowt);

		uptime = ticks() / 60L;
		days = (int)(uptime / 86400L);
		uptime = uptime - (long)days * 86400L;
		hrs = (int)(uptime / 3600L);
		uptime = uptime - (long)hrs * 3600L;
		mins = (int)DIV60(uptime);

		printf("  up");
		if (days > 0)
			printf(" %d day%s,", days, days > 1 ? "s" : "");
		if (hrs > 0 && mins > 0) {
			printf(" %2d:%02d,", hrs, mins);
		} else {
			if (hrs > 0)
				printf(" %d hr%s,", hrs, hrs > 1 ? "s" : "");
			if (mins > 0)
				printf(" %d min%s,", mins, mins > 1 ? "s" : "");
		}

		/* Print number of users logged in to system */
		if (ut != (FILE *)0) {
			while (fread((char *)&utmp, sizeof(struct utmp), 1, ut)
			       == 1)
				if (utmp.ut_name[0] != '\0')
					nusers++;
			rewind(ut);
		}
		printf("  %d user%s\n", nusers, nusers == 1 ? "" : "s");
		if (wcmd == 0)
			exit(0);

		/* Headers for rest of output */
		if (lflag)
			printf("%-8.8s %-8.8s  login@  what\n", "User", "tty");
		else
			printf("%-8.8s tty what\n", "User");
		fflush(stdout);
	}

	if (ut == (FILE *)0) {
		fprintf(stderr, "%s: cannot open %s\n", program, _PATH_UTMP);
		exit(1);
	}

	for (;;) {	/* for each entry in utmp */
		if (fread((char *)&utmp, sizeof(struct utmp), 1, ut) != 1) {
			fclose(ut);
			exit(0);
		}
		if (utmp.ut_name[0] == '\0')
			continue;	/* that tty is free */
		if (sel_user != (char *)0
		 && strncmp(utmp.ut_name, sel_user, NMAX) != 0)
			continue;	/* we wanted only somebody else */

		strcpy(doing, "-");	/* default act: normally never prints */
		curpid = -1;
		for (i = 0; i < np; i++) {	/* for each process on this tty */
			if (pr[i].pid == 0 || pr[i].state == 4
			 || pr[i].pgid == 0)
				continue;	/* the kernel, a zombie, no session */
			if (strncmp(pr[i].ttyname, utmp.ut_line, PROC_TTY_MAX)
			    != 0)
				continue;
			if (pr[i].pid > curpid) {
				curpid = pr[i].pid;
				strncpy(doing, pr[i].name, PROC_NAME_MAX);
				doing[PROC_NAME_MAX] = '\0';
			}
		}
		putline();
	}
}

/*
 * putline: print out the accumulated line of info about one user.
 */
int
putline()
{
	long t;

	/* print login name of the user */
	printf("%-8.8s ", utmp.ut_name);

	/* print tty user is on */
	if (lflag)
		/* long form: all (up to) LMAX chars */
		printf("%-8.8s", utmp.ut_line);
	else {
		/* short form: 2 chars, skipping 'tty' if there */
		if (utmp.ut_line[0] == 't' && utmp.ut_line[1] == 't'
		 && utmp.ut_line[2] == 'y')
			printf("%-2.2s", &utmp.ut_line[3]);
		else
			printf("%-2.2s", utmp.ut_line);
	}

	if (lflag) {
		/* print when the user logged in */
		t = utmp.ut_time;
		prtat(localtime(&t));
	}

	/* what user is doing: the command name */
	printf(" %-.16s\n", doing);
	fflush(stdout);
	return 0;
}

/*
 * prttime prints a time in hours and minutes.
 * The character string tail is printed at the end, obvious
 * strings to pass are "", " ", or "am".
 */
int
prttime(tim, tail)
	long tim;
	char *tail;
{
	int didhrs = 0;

	if (tim >= 60L) {
		printf("%3ld:", tim / 60L);
		didhrs++;
	} else {
		printf("    ");
	}
	tim = tim % 60L;
	if (tim > 0L || didhrs) {
		/* upstream selects the format inside the call:
		 * printf(didhrs&&tim<10 ? "%02ld" : "%2ld", tim) */
		if (didhrs && tim < 10L)
			printf("%02ld", tim);
		else
			printf("%2ld", tim);
	} else {
		printf("  ");
	}
	printf("%s", tail);
	return 0;
}

/* prtat prints a 12 hour time given a pointer to a time of day */
int
prtat(p)
	struct tm *p;
{
	int pm;
	long t;

	t = p->tm_hour;
	pm = (t > 11L);
	if (t > 11L)
		t -= 12L;
	if (t == 0L)
		t = 12L;
	prttime(t * 60L + (long)p->tm_min, pm ? "pm" : "am");
	return 0;
}

/*
 * readpr reads in the array pr: one procs(2) record per task.  Upstream
 * filters SZOMB, p_stat 0 and p_pgrp 0 here; the scan in main() applies the
 * same three tests to the record fields instead, which saves compacting the
 * array.
 */
int
readpr()
{
	np = procs((char *)pr, NPR);
	if (np < 0)
		np = 0;
	return 0;
}

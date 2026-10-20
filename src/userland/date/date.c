/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD date(1)
 *   Ported from date(1), 2.11BSD (date.c 4.20.1 1996/7/10; Berkeley), with
 *   patch #454 (date.c 5.0, 2019/10/20).
 *   Copyright (c) 1985 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * H1 of the hand-asm retirement roadmap; replaces the hand-asm date.s
 * (which printed ISO "YYYY-MM-DD HH:MM:SS" and could not set the clock).
 *
 * Patch #454 is the time zone model: the time given is local time in TZ
 * (else /etc/localtime), converted to UTC with the tm_gmtoff localtime
 * reports for it, and -u sets TZ=GMT.  The kernel's struct timezone is
 * neither read nor set.
 *
 * FGX adaptations (each is a missing-OS-concept scope; the display path
 * and the yymmddhhmm[.ss] set parser are faithful 2.11BSD):
 *   - No timed(8): -n and the whole netsettime/TSP protocol are gone --
 *     setting is always local.
 *   - No wtmp/syslog/getlogin: single-user FGX has none of them; the
 *     set path sets the kernel clock through settimeofday, which writes
 *     the battery clock back itself, and re-displays.
 *   - gtime's `*C = NULL` 2.11-ism is `*C = '\0'`.
 */
#include <sys/time.h>
#include <errno.h>
#include <tzfile.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

#define	ATOI2(ar)	(ar[0] - '0') * 10 + (ar[1] - '0'); ar += 2;

static struct timeval	tv;
static int	retval;

static int	dmsize[] =
	{ -1, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

int gtime();
extern int optind;

int main(argc, argv)
	int	argc;
	char	**argv;
{
	static char	usage[] = "usage: date [-u] [[[[yy]mm]dd]hhmm[.ss]]\n";
	struct tm	*tp;
	char	*ap,			/* time string */
		*tzn;			/* time zone */
	int	ch;

	while ((ch = getopt(argc, argv, "u")) != EOF)
		switch ((char)ch) {
		case 'u':
			(void)setenv("TZ", "GMT", 1);
			break;
		default:
			fputs(usage, stderr);
			exit(1);
		}
	argc -= optind;
	argv += optind;

	if (argc > 1) {
		fputs(usage, stderr);
		exit(1);
	}

	if (!argc)
		goto display;

	time(&tv.tv_sec);

	if (gtime(*argv)) {
		fputs(usage, stderr);
		retval = 1;
		goto display;
	}

/*
 * To avoid using the (obsolete) kernel timezone structure call localtime()
 * to initialize the timezone info and set tm_gmtoff
*/
	tp = localtime(&tv.tv_sec);
	tv.tv_sec -= tp->tm_gmtoff;

	if (settimeofday(&tv, (struct timezone *)0)) {
		fputs("date: settimeofday failed\n", stderr);
		retval = 1;
		goto display;
	}

display:
	if (gettimeofday(&tv, (struct timezone *)0)) {
		fputs("date: gettimeofday failed\n", stderr);
		exit(1);
	}
/*
 * Now display the time
*/
	tp = localtime(&tv.tv_sec);
	ap = asctime(tp);
	tzn = tp->tm_zone;
	printf("%.20s%s%s", ap, tzn, ap + 19);
	exit(retval);
}

/*
 * gtime --
 *	convert user's time into number of seconds
 */
int gtime(ap)
	register char	*ap;		/* user argument */
{
	register int	year, month;
	register char	*C;		/* pointer into time argument */
	struct tm	*L;
	int	day, hour, mins, secs;

	for (secs = 0, C = ap; *C; ++C) {
		if (*C == '.') {		/* seconds provided */
			if (strlen(C) != 3)
				return (1);
			*C = '\0';
			secs = (C[1] - '0') * 10 + (C[2] - '0');
			break;
		}
		if (!isdigit(*C))
			return (-1);
	}

	L = localtime(&tv.tv_sec);
	year = L->tm_year;			/* defaults */
	month = L->tm_mon + 1;
	day = L->tm_mday;

	switch ((int)(C - ap)) {		/* length */
		case 10:			/* yymmddhhmm */
			year = ATOI2(ap);
		case 8:				/* mmddhhmm */
			month = ATOI2(ap);
		case 6:				/* ddhhmm */
			day = ATOI2(ap);
		case 4:				/* hhmm */
			hour = ATOI2(ap);
			mins = ATOI2(ap);
			break;
		default:
			return (1);
	}

	if (*ap || month < 1 || month > 12 || day < 1 || day > 31 ||
	    mins < 0 || mins > 59 || secs < 0 || secs > 59)
		return (1);
	if (hour == 24) {
		++day;
		hour = 0;
	}
	else if (hour < 0 || hour > 23)
		return (1);

	tv.tv_sec = 0;
	year += TM_YEAR_BASE;
/* If year < EPOCH_YEAR, assume it's in the next century and
   the system has not yet been patched to move TM_YEAR_BASE up yet */
	if (year < EPOCH_YEAR)
		year += 100;
	if (isleap(year) && month > 2)
		++tv.tv_sec;
	for (--year; year >= EPOCH_YEAR; --year)
		tv.tv_sec += isleap(year) ? DAYS_PER_LYEAR : DAYS_PER_NYEAR;
	while (--month)
		tv.tv_sec += dmsize[month];
	tv.tv_sec += day - 1;
	tv.tv_sec = HOURS_PER_DAY * tv.tv_sec + hour;
	tv.tv_sec = MINS_PER_HOUR * tv.tv_sec + mins;
	tv.tv_sec = SECS_PER_MIN * tv.tv_sec + secs;
	return (0);
}

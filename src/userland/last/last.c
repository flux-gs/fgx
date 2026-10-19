/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD last(1)
 *   Ported from last(1), 2.11BSD (last.c 5.3 (Berkeley) 5/15/86,
 *   vendor/2.11BSD/usr/ucb/last.c).
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* last - list the sessions in /etc/wtmp, most recent first.
 *
 * THE BODY IS 2.11BSD's, with two edits and no third.  (1) The default wtmp is
 * _PATH_WTMP ("/etc/wtmp"), not upstream's "/usr/adm/wtmp" -- FGX keeps the log
 * where <utmp.h> names it and login(3)/init(8) write it.  (2) The headers that
 * upstream leaves implicit are included, because a function fcc does not see a
 * prototype for is assumed to return int, and int is 16 bits here: ctime(),
 * gmtime(), asctime(), getpwnam() and malloc() all return a 24-bit pointer
 * whose bank byte an implicit-int declaration would drop (the "far-pointer
 * return loses its bank" trap).  <time.h> gives the three time calls their real
 * returns, and localtime == gmtime on FGX because the epoch is local, which is
 * exactly what the delta formatting below assumes.
 *
 * The record layout is FGX's 36-byte utmp (UT_NAMESIZE 8), so the NMAX/LMAX/HMAX
 * that size every field come out 8/8/16 rather than 2.11BSD's 15/8/16; the code
 * reads them from sizeof, so nothing here depends on the number.
 *
 * SIGQUIT (Ctrl-\) is defined but the kernel does not deliver it (signal.s maps
 * five signals and quit is not one), so its handler never runs; the arming is
 * kept verbatim rather than pruned, and does no harm.
 */
#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>             /* malloc, atoi, exit: far/return-value correct */
#include <string.h>
#include <signal.h>
#include <time.h>              /* ctime/gmtime/asctime: 24-bit returns, prototyped */
#include <pwd.h>               /* getpwnam: 24-bit return, prototyped */
#include <unistd.h>            /* open/read/lseek/close */
#include <utmp.h>

#define NMAX	sizeof(buf[0].ut_name)
#define LMAX	sizeof(buf[0].ut_line)
#define	HMAX	sizeof(buf[0].ut_host)
#define	SECDAY	((long)24*60*60)

#define	lineq(a,b)	(!strncmp(a,b,LMAX))
#define	nameq(a,b)	(!strncmp(a,b,NMAX))
#define	hosteq(a,b)	(!strncmp(a,b,HMAX))

#define MAXTTYS 256

char	**argv;
int	argc;
int	nameargs;

struct	utmp buf[128];
char	ttnames[MAXTTYS][LMAX+1];
long	logouts[MAXTTYS];

char	*strspl();
int	onintr();

main(ac, av)
	char **av;
{
	register int i, k;
	int wtmp;
	off_t bl;
	char *ct;
	char wtmpfile[256];
	char progname[256];
	register struct utmp *bp;
	long otime;
	struct stat stb;
	int print;
	int sinput = 0;
	char * crmsg = (char *)0;
	long crtime;
	long outrec = 0;
	long maxrec = 0x7fffffffL;

	time(&buf[0].ut_time);
	strcpy(wtmpfile, _PATH_WTMP);
	strcpy(progname,av[0]);
	ac--, av++;
	nameargs = argc = ac;
	argv = av;
	for (i = 0; i < argc; i++) {
		if (argv[i][0] == '-' ) {
			if ( argv[i][1] >= '0' && argv[i][1] <= '9') {
				maxrec = atoi(argv[i]+1);
				nameargs--;
				continue;
			} else {
				if (argv[i][1] == 'f') {
					i++;
					if ( i < argc) {
						strcpy(wtmpfile,argv[i]);
						nameargs = nameargs -2;
						continue;
					} else {
						usage(progname);
					}
				} else {
					usage(progname);
				}
			}
		}
		if (strlen(argv[i])>2)
			continue;
		if (!strcmp(argv[i], "~"))
			continue;
		if (!strcmp(argv[i], "ftp"))
			continue;
		if (!strcmp(argv[i], "uucp"))
			continue;
		if (getpwnam(argv[i]))
			continue;
		argv[i] = strspl("tty", argv[i]);
	}
	wtmp = open(wtmpfile, 0);
	if (wtmp < 0) {
		perror(wtmpfile);
		exit(1);
	}
	fstat(wtmp, &stb);
	bl = (stb.st_size + sizeof (buf)-1) / sizeof (buf);
	if (signal(SIGINT, SIG_IGN) != SIG_IGN) {
		signal(SIGINT, onintr);
		signal(SIGQUIT, onintr);
	}
	for (bl--; bl >= 0; bl--) {
		lseek(wtmp, bl * sizeof (buf), 0);
		bp = &buf[read(wtmp, buf, sizeof (buf)) / sizeof(buf[0]) - 1];
		for ( ; bp >= buf; bp--) {
			print = want(bp);
			if (print) {
				ct = ctime(&bp->ut_time);
				printf("%-*.*s  %-*.*s %-*.*s %10.10s %5.5s ",
				    NMAX, NMAX, bp->ut_name,
				    LMAX, LMAX, bp->ut_line,
				    HMAX, HMAX, bp->ut_host,
				    ct, 11+ct);
			}
			for (i = 0; i < MAXTTYS; i++) {
				if (ttnames[i][0] == 0) {
					strncpy(ttnames[i], bp->ut_line,
					    sizeof(bp->ut_line));
					otime = logouts[i];
					logouts[i] = bp->ut_time;
					break;
				}
				if (lineq(ttnames[i], bp->ut_line)) {
					otime = logouts[i];
					logouts[i] = bp->ut_time;
					break;
				}
			}
			if (print) {
				if (lineq(bp->ut_line, "~"))
					printf("\n");
				else if (otime == 0)
					printf("  still logged in\n");
				else {
					long delta;
					if (otime < 0) {
						otime = -otime;
						printf("- %s", crmsg);
					} else
						printf("- %5.5s",
						    ctime(&otime)+11);
					delta = otime - bp->ut_time;
					if (delta < SECDAY)
					    printf("  (%5.5s)\n",
						asctime(gmtime(&delta))+11);
					else
					    printf(" (%ld+%5.5s)\n",
						delta / SECDAY,
						asctime(gmtime(&delta))+11);
				}
				fflush(stdout);
				if (++outrec >= maxrec)
					exit(0);
			}
			if (lineq(bp->ut_line, "~")) {
				for (i = 0; i < MAXTTYS; i++)
					logouts[i] = -bp->ut_time;
				if (nameq(bp->ut_name, "shutdown"))
					crmsg = "down ";
				else
					crmsg = "crash";
			}
		}
	}
	ct = ctime(&buf[0].ut_time);
	printf("\nwtmp begins %10.10s %5.5s \n", ct, ct + 11);
	exit(0);
}

onintr(signo)
	int signo;
{
	char *ct;

	if (signo == SIGQUIT)
		signal(SIGQUIT, onintr);
	ct = ctime(&buf[0].ut_time);
	printf("\ninterrupted %10.10s %5.5s \n", ct, ct + 11);
	fflush(stdout);
	if (signo == SIGINT)
		exit(1);
}

want(bp)
	struct utmp *bp;
{
	register char **av;
	register int ac;

	if (bp->ut_line[0] == '~' && bp->ut_name[0] == '\0')
		strcpy(bp->ut_name, "reboot");		/* bandaid */
	if (strncmp(bp->ut_line, "ftp", 3) == 0)
		bp->ut_line[3] = '\0';
	if (strncmp(bp->ut_line, "uucp", 4) == 0)
		bp->ut_line[4] = '\0';
	if (bp->ut_name[0] == 0)
		return (0);
	if (nameargs == 0)
		return (1);
	av = argv;
	for (ac = 0; ac < argc; ac++, av++) {
		if (av[0][0] == '-')
			continue;
		if (nameq(*av, bp->ut_name) || lineq(*av, bp->ut_line))
			return (1);
	}
	return (0);
}

char *
strspl(left, right)
	char *left, *right;
{
	char *res = (char *)malloc(strlen(left)+strlen(right)+1);

	strcpy(res, left);
	strcat(res, right);
	return (res);
}

void
usage(progname)
	char *progname;
{
	printf("Usage: %s [ -f filename ] [-number] [name...] [tty...]\n",
		progname);
	exit(1);
}

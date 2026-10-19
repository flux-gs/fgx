/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD who(1)
 *   Ported from who(1), 2.11BSD (who.c 5.1.3 (2.11BSD GTE) 1997/7/29,
 *   vendor/2.11BSD/usr/bin/who.c).
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* who - who is on the system.
 *
 * NOT ONE LINE OF THE BODY IS CHANGED.  The /etc/utmp walk, the optional
 * who-file operand, `who am i' and putline() are upstream's, down to the `*'
 * width arguments and the in-loop gethostname() -- which is where upstream
 * puts it, once per record rather than once per run.
 *
 * `tp = rindex(tp, '/') + 1' IS UPSTREAM'S AND IS SAFE HERE: ttyname(3) builds
 * its answer as _TTYNAME_PFX + the FIODGNAME name (libc_c/ttyname.c), so it
 * either returns a path containing `/dev/' or returns NULL, and the NULL is
 * what the else arm is for.
 *
 * Three things this port was expected to need and does not: printf here
 * implements `*' width and precision (libc_c/printf.c), rindex is a libc name
 * (alias.c), and fcc takes the address of a long struct member, so
 * `ctime(&utmp.ut_time)' is written as upstream writes it.
 */
#include <stdio.h>
#include <stdlib.h>
#include <utmp.h>
#include <pwd.h>
#include <string.h>
#include <strings.h>            /* rindex */
#include <time.h>
#include <unistd.h>
#include <sys/param.h>          /* MAXHOSTNAMELEN */

#define NMAX sizeof(utmp.ut_name)
#define LMAX sizeof(utmp.ut_line)
#define	HMAX sizeof(utmp.ut_host)

struct	utmp utmp;
struct	passwd *pw;
char	hostname[MAXHOSTNAMELEN];

int	putline();

int
main(argc, argv)
	int argc;
	char **argv;
{
	char *tp, *s;
	FILE *fi;

	s = _PATH_UTMP;
	if(argc == 2)
		s = argv[1];
	if (argc == 3) {
		tp = ttyname(0);
		if (tp)
			tp = rindex(tp, '/') + 1;
		else {	/* no tty - use best guess from passwd file */
			pw = getpwuid(getuid());
			strncpy(utmp.ut_name, pw ? pw->pw_name : "?", NMAX);
			strcpy(utmp.ut_line, "tty??");
			time(&utmp.ut_time);
			putline();
			exit(0);
		}
	}
	if ((fi = fopen(s, "r")) == NULL) {
		fprintf(stderr, "who: cannot open %s\n", s);
		exit(1);
	}
	while (fread((char *)&utmp, sizeof(utmp), 1, fi) == 1) {
		if (argc == 3) {
			gethostname(hostname, sizeof (hostname));
			if (strcmp(utmp.ut_line, tp))
				continue;
			printf("%s!", hostname);
			putline();
			exit(0);
		}
		if (utmp.ut_name[0] == '\0' && argc == 1)
			continue;
		putline();
	}
	return 0;
}

int
putline()
{
	char *cbuf;

	printf("%-*.*s %-*.*s",
		NMAX, NMAX, utmp.ut_name,
		LMAX, LMAX, utmp.ut_line);
	cbuf = ctime(&utmp.ut_time);
	printf("%.12s", cbuf+4);
	if (utmp.ut_host[0])
		printf("\t(%.*s)", HMAX, utmp.ut_host);
	putchar('\n');
	return 0;
}

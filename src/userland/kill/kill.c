/*
 * SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD kill(1)
 *   Ported from kill(1), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *
 * kill - send signal to process
 *
 * Upstream is @(#)kill.c 4.4.1 (2.11BSD) 1996/3/21, vendored at
 * vendor/2.11BSD/usr/bin/kill.c.
 *
 * REPLACES A HAND-ROLLED kill(1) that parsed its operand with a bare atoi().
 * `%` is a csh JOB SPEC and no /bin/kill has ever understood one, so `kill %`
 * has to be a usage error -- but atoi("%") is 0, and kill(0, sig) is "signal
 * every task in MY process group" (2.11BSD kern_sig.c killpg1).  A mistyped job
 * spec therefore fanned SIGTERM across the caller's whole session instead of
 * printing usage; it spared the login shell only because an interactive shell
 * ignores SIGTERM.  apple/fgx#126 has the measurement.  The guard that prevents
 * it is upstream's, and was simply missing here:
 *
 *      if (!(isdigit(**argv) || **argv == '-'))
 *              goto usage;
 *
 * The man page FGX already shipped (man/pages/cat1/kill.0, the verbatim 2.11BSD
 * page) documented the correct interface the whole time -- including "Kill is a
 * built-in to csh(1); it allows job specifiers of the form ``%...''" -- along
 * with -l, signal NAMES and several pids per invocation, none of which the
 * hand-rolled version implemented.  This port makes the binary match its own
 * documentation.
 *
 * The name table is upstream's verbatim, which is why signal 6 is "IOT" rather
 * than FGX's SIGABRT spelling: `kill -IOT` is what a 2.11BSD script types.  It
 * needs no renumbering -- FGX's signal.h matches 2.11BSD one for one, gap at 29
 * included.
 *
 * ADAPTATIONS, in full: declarations are explicitly `int` where upstream relied
 * on implicit-int (`register signo, pid, res;`, `extern errno;`); errno comes
 * from <errno.h> rather than a bare `extern errno`; main carries an explicit
 * `int` return type; the SCCS id string is dropped; and the headers upstream got
 * implicitly are included by name.  The body is otherwise statement-for-statement
 * upstream's, `char *name`'s block scope included.
 */
#include <signal.h>
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *signm[] = { 0,
"HUP", "INT", "QUIT", "ILL", "TRAP", "IOT", "EMT", "FPE",	/* 1-8 */
"KILL", "BUS", "SEGV", "SYS", "PIPE", "ALRM", "TERM", "URG",	/* 9-16 */
"STOP", "TSTP", "CONT", "CHLD", "TTIN", "TTOU", "IO", "XCPU",	/* 17-24 */
"XFSZ", "VTALRM", "PROF", "WINCH", 0, "USR1", "USR2", 0,	/* 25-31 */
};

int
main(argc, argv)
int argc;
char **argv;
{
	int signo, pid, res;
	int errlev;

	errlev = 0;
	if (argc <= 1) {
	usage:
		printf("usage: kill [ -sig ] pid ...\n");
		printf("for a list of signals: kill -l\n");
		exit(2);
	}
	if (*argv[1] == '-') {
		if (argv[1][1] == 'l') {
			for (signo = 0; signo <= NSIG; signo++) {
				if (signm[signo])
					printf("%s ", signm[signo]);
				if (signo == 16)
					printf("\n");
			}
			printf("\n");
			exit(0);
		} else if (isdigit(argv[1][1])) {
			signo = atoi(argv[1]+1);
			if (signo < 0 || signo > NSIG) {
				printf("kill: %s: number out of range\n",
				    argv[1]);
				exit(1);
			}
		} else {
			char *name = argv[1]+1;
			for (signo = 0; signo <= NSIG; signo++)
				if (signm[signo] && !strcmp(signm[signo], name))
					goto foundsig;
			printf("kill: %s: unknown signal; kill -l lists signals\n", name);
			exit(1);
foundsig:
			;
		}
		argc--;
		argv++;
	} else
		signo = SIGTERM;
	argv++;
	while (argc > 1) {
		if (!(isdigit(**argv) || **argv == '-'))
			goto usage;
		res = kill(pid = atoi(*argv), signo);
		if (res < 0) {
			printf("%u: %s\n", pid, strerror(errno));
			errlev = 1;
		}
		argc--;
		argv++;
	}
	return (errlev);
}

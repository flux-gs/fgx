/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 4.4BSD/NetBSD-0.9 tput(1)
 *   Ported from tput(1), NetBSD 0.9 (tput.c 5.7, Berkeley, 6/7/90).  Original
 *   work: Copyright (c) 1980, 1988 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX changes
 *   are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * tput -- initialize a terminal or query the termcap database: for each
 * operand, emit its string capability (clear, bold, cd, ...), print its numeric
 * capability (cols, lines), or set the exit status from its boolean capability.
 * Lets shell scripts drive the console through termcap rather than baking in
 * escape sequences.  Generalizes clear(1) (which is just `tput cl`).
 *
 * FGX/fcc adaptations (no meaningful feature loss):
 *  - getopt -> a 2-line "-T term" scan (fcc libc has no getopt; this is the
 *    tool's only option).
 *  - getenv("TERM") may be unset; like clear(1)/ul(1) we default to "fgx" --
 *    FGX has exactly one terminal (the SHR console) and tgetent is baked.
 *  - setospeed()/ospeed/tcgetattr dropped: those feed tputs's serial padding
 *    DELAY, moot on a memory-mapped SHR console (our tputs parses but never
 *    delays).  Dropping them also drops the only <sys/termios.h> dependency.
 *  - tputs/putch defined here (fcc libc has neither); copied from clear(1)/ul(1).
 *  - `longname` prints the resolved term name: FGX's baked tgetent does not
 *    populate the entry buffer, so the BSD prlongname()/'|'-split can't run.
 *  - streq() local helper instead of strcmp() (fcc treats strcmp as a libc
 *    builtin; declaring it clashes with the host cproto/ansify step -- see jsh).
 */
/*
 * Copyright (c) 1980, 1988 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#ifndef lint
static char sccsid[] = "@(#)tput.c\t5.7 (Berkeley) 6/7/90";
#endif not lint

#include <stdio.h>

/* libc decls not provided by <stdio.h> -- fcc requires a prototype even for
 * bound calls.  tgetent/tgetstr/tgetnum/tgetflag are the C-callable termcap
 * bridge (fcc_libc_shims.s); getenv is libc. */
void  exit(int code);
char *getenv(char *name);
int   tgetent(char *bp, char *name);
char *tgetstr(char *id, char **area);
int   tgetnum(char *id);
int   tgetflag(char *id);

/* ANSI forward prototypes (tools/ansify.sh via cproto) */
int  main(int argc, char **argv);
int  streq(char *a, char *b);
int  putch(int c);
void usage(void);

int
main(int argc, char **argv)
{
	char *term;
	char *p;
	char *cp;
	char *ap;
	char  tbuf[64];		/* baked tgetent ignores it; small (frame) */
	char  area[128];	/* tgetstr copies the cap string here */
	int   i, n, exitval;

	term = 0;
	i = 1;
	/* the only option is "-T term"; scan it without getopt */
	if (argc > 2 && argv[1][0] == '-' && argv[1][1] == 'T' &&
	    argv[1][2] == '\0') {
		term = argv[2];
		i = 3;
	}
	if (term == 0)
		term = getenv("TERM");
	if (term == 0)
		term = "fgx";		/* single console */

	if (tgetent(tbuf, term) != 1) {
		fprintf(stderr, "tput: tgetent failure.\n");
		exit(2);
	}

	exitval = 0;
	for (; i < argc; i++) {
		p = argv[i];
		/* operand aliases (BSD): map friendly names to capnames */
		if (streq(p, "clear"))
			p = "cl";
		else if (streq(p, "init"))
			p = "is";
		else if (streq(p, "reset"))
			p = "rs";
		else if (streq(p, "longname")) {
			/* baked tgetent has no entry buffer -- print the type */
			printf("%s\n", term);
			continue;
		}

		ap = area;
		cp = tgetstr(p, &ap);
		if (cp != 0) {
			tputs(cp, 1, putch);
		} else {
			n = tgetnum(p);
			if (n != -1)
				printf("%d\n", n);
			else
				exitval = !tgetflag(p);
		}
	}
	exit(exitval);
}

/* streq -- strcmp()==0 without pulling in the strcmp builtin prototype. */
int
streq(char *a, char *b)
{
	while (*a && *a == *b) {
		a++;
		b++;
	}
	return *a == *b;
}

/* fcc's libc has no putch; stdio fputc writes immediately. */
int
putch(int c)
{
	fputc(c, stdout);
	return c;
}

/* tputs now comes from libtermlib (BSD-foundations P1) — the local copy
 * this comment anchored is retired; the tool selects libs="termlib".
 * UP and BC below are tentative definitions: libtermlib defines them, as
 * 2.11BSD's tgoto.c does, and K&R A.10.2's common extension merges the
 * two (this tool never calls tgoto, so they stay null). */
char *UP;
char *BC;
/* RTL-ABI: termlib compiles tputs/tgoto behind EMPTY-PAREN forward
 * decls (the fcc variadic flip, matching elvis's K&R externs) — every
 * client must declare them the same way or the args land reversed. */
void tputs();

void
usage(void)
{
	fprintf(stderr, "usage: tput [-T term] attribute ...\n");
	exit(1);
}

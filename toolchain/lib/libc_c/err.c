/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* err.c -- err(3): err, errx, warn, warnx and their v-forms.
 *
 * FGX-Provenance: 2.11BSD lib/libc/gen/err.c
 *   Ported from err(3), 2.11BSD (8.1.1 (2.11BSD GTE) 2/3/95).  Original work:
 *   Copyright (c) 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * VERBATIM BUT FOR THE VARARGS BRANCHES.  Upstream carries every variadic
 * function twice, `#ifdef __STDC__' selecting <stdarg.h> against <varargs.h>.
 * fcc is a K&R compiler that provides <stdarg.h> and not <varargs.h> -- the
 * two-argument `va_start(ap, fmt)' is what printf.c has always used -- so the
 * __STDC__ branch is the one kept and the varargs branch is dropped rather
 * than left to fail.  `const' goes with it, being the non-STDC spelling.
 * Nothing else is touched: putprog/putcolsp, the sverrno save before the
 * format is printed, and the exact punctuation are upstream's.
 *
 * WHAT IT NEEDED THAT DID NOT EXIST: vfprintf(3).  printf.c had the engine
 * (__lc_vpf) and vsprintf as its sprintf-mode wrapper, and no stdio-mode one;
 * verr and vwarn are its first callers.  __progname is crt0's, and has been
 * since the first FGX binary -- err(3) is simply the first thing to read it.
 *
 * df(1) is why this landed (apple/fgx#329): its error path is `warn("%s",
 * *argv)', and the standing rule is that a port's gaps get filled in libc
 * rather than edited out of the source.
 */
#include <err.h>

/* __progname IS NOT crt0's CELL, AND CANNOT BE.
 *
 * Upstream declares `extern char *__progname;  /* Program name, from crt0. *``/'
 * and 2.11BSD's crt0 sets it.  FGX's crt0 sets one too -- args_data.s:25,
 * `__progname DA 0', written by _crt0_set_progname from basename(argv[0]) --
 * but that cell is a 2-BYTE near offset into the program's data bank, and an
 * fcc pointer is FOUR bytes with a bank.  `extern char *__progname' over it
 * would read two bytes of pointer and two bytes of whatever args_optind and
 * friends hold.
 *
 * AND DECLARING A C `__progname' BESIDE IT IS A LINK ERROR, which is how this
 * was settled rather than guessed: merlin32 reports "Found label name
 * '__progname' in both source files 'libc.sel.data.s' and
 * '../../toolchain/lib/args_data.s'".  The two cannot coexist, so there is no
 * C object of that name at all.
 *
 * args_argv IS four bytes per entry (`args_argv DS 4*ARGS_MAX' -- the same
 * far-pointer width fcc uses), so the name is derived from args_argv[0]
 * instead, which is the string crt0's own basename walk started from.  Same
 * answer, reached through the one cell whose width already matches, cached in
 * a static so the walk happens once.
 *
 * WHAT IS LOST is upstream's settable global: a BSD program may assign
 * `__progname' to change what err(3) prints, and none here can.  Nothing in
 * this tree does, and the alternative is renaming the assembler's cell --
 * which crt0 writes and every binary links.  Stated rather than papered. */
extern char *args_argv[];

static	void	putprog(), putcolsp();

void
err(int eval, char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	verr(eval, fmt, ap);
	va_end(ap);
}

void
verr(eval, fmt, ap)
	int eval;
	char *fmt;
	va_list ap;
{
	int sverrno;

	sverrno = errno;
	putprog();
	if (fmt != NULL) {
		(void)vfprintf(stderr, fmt, ap);
		putcolsp();
	}
	(void)fputs(strerror(sverrno), stderr);
	(void)fputc('\n', stderr);
	exit(eval);
}

void
errx(int eval, char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	verrx(eval, fmt, ap);
	va_end(ap);
}

void
verrx(eval, fmt, ap)
	int eval;
	char *fmt;
	va_list ap;
{
	putprog();
	if (fmt != NULL)
		(void)vfprintf(stderr, fmt, ap);
	(void)fputc('\n', stderr);
	exit(eval);
}

void
warn(char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	vwarn(fmt, ap);
	va_end(ap);
}

void
vwarn(fmt, ap)
	char *fmt;
	va_list ap;
{
	int sverrno;

	sverrno = errno;
	putprog();
	if (fmt != NULL) {
		(void)vfprintf(stderr, fmt, ap);
		putcolsp();
	}
	(void)fputs(strerror(sverrno), stderr);
	(void)fputc('\n', stderr);
}

void
warnx(char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	vwarnx(fmt, ap);
	va_end(ap);
}

void
vwarnx(fmt, ap)
	char *fmt;
	va_list ap;
{
	putprog();
	if (fmt != NULL)
		(void)vfprintf(stderr, fmt, ap);
	(void)fputc('\n', stderr);
}

/*
 * Helper routines.  Repeated constructs of the form "%s: " used up too
 * much D space.  On a pdp-11 code can be overlaid but Data space is worth
 * conserving.  An extra function call or two handling an error condition is
 * a reasonable trade for 20 or 30 bytes of D space.
*/

static void
putprog()
	{
	register char *p, *b;
	static char *progname;

	if (progname == 0 && args_argv[0] != 0) {
		/* basename: past the last '/', which is crt0's own rule and
		 * BSD's -- "No '/' -> __progname = ptr to whole" (crt0.s:210). */
		b = args_argv[0];
		for (p = b; *p; p++)
			if (*p == '/')
				b = p + 1;
		progname = b;
	}
	if (progname == 0)
		return;
	fputs(progname, stderr);
	putcolsp();
	}

static void
putcolsp()
	{

	fputc(':', stderr);
	fputc(' ', stderr);
	}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD clear(1)
 *   Ported from clear(1), 2.11BSD (clear.c 5.1, Berkeley, 5/31/85).  Original
 *   work: Copyright (c) 1980 Regents of the University of California.  All
 *   rights reserved.  UCB notice retained per the BSD license; FGX changes are
 *   BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * clear -- clear the terminal screen by emitting the termcap `cl` string.
 *
 * Supersedes the prior FGX-original hardcode `write(1,"\033[H\033[2J",7)`:
 * clear is now driven by the libc termcap table through the C-callable bridge
 * (tgetent/tgetstr/tgetnum), so its output tracks whatever the console's real
 * `cl` sequence is rather than a literal baked into this tool.  On FGX
 * tgetstr("cl") returns ESC[H ESC[2J -- the *same 7 bytes* the old clear wrote,
 * so this port is byte-for-byte identical on screen.  It is also the first
 * consumer of tgetnum (the bridge fn ul(1) never exercised).
 *
 * FGX/fcc adaptations (no feature loss):
 *  - Dropped the sgtty gtty(1,&tty)/ospeed and the PC padding char: both feed
 *    tputs's serial padding DELAY, which is moot on a memory-mapped SHR console
 *    (our tputs parses the padding spec but emits no delay).  FGX has no
 *    sgtty/gtty yet (vi slice 4.3); when it lands, this can pad properly.
 *  - tputs/putch are defined here (fcc's libc has neither); copied from
 *    ul(1).  vi slice 4.2 factors tputs into a shared termlib.
 *  - TERM-unset no longer exit(1)s: FGX has exactly one terminal (the SHR
 *    console) and tgetent is baked, so clear should always just clear.  We
 *    default the type (like ul(1)) instead of refusing.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#ifndef lint
static char sccsid[] = "@(#)clear.c\t5.1 (Berkeley) 5/31/85";
#endif not lint

#include <stdio.h>

/* libc decls not provided by <stdio.h> -- fcc requires a prototype even for
 * bound calls.  tgetent/tgetstr/tgetnum are the C-callable termcap bridge
 * (fcc_libc_shims.s). */
void  exit(int code);
char *getenv(char *name);
int   tgetent(char *bp, char *name);
char *tgetstr(char *id, char **area);
int   tgetnum(char *id);

/* ANSI forward prototypes (tools/ansify.sh via cproto) */
int  main(int argc, char **argv);
int  putch(int c);

int
main(int argc, char **argv)
{
	char *cp;
	char *clear;
	char *clbp;
	char  clbuf[20];
	char  termcap[32];	/* baked tgetent ignores it; keep small (frame) */

	cp = getenv("TERM");
	if (cp == NULL)
		cp = "fgx";		/* single console -- always clear */

	if (tgetent(termcap, cp) != 1)
		exit(1);

	clbp = clbuf;
	clear = tgetstr("cl", &clbp);
	if (clear)
		tputs(clear, tgetnum("li"), putch);

	if (clear == NULL)
		exit(1);		/* no cl cap -- nothing emitted */
	exit(0);
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

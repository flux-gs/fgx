/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libcurses (printw.c, Berkeley 6/7/85 era)
 *   Ported from usr.lib/libcurses (4.3BSD curses as shipped in 2.11BSD).
 *   Original work: Copyright (c) 1980 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if !defined(lint) && !defined(NOSCCS)
static char sccsid[] = "@(#)printw.c	5.1 (Berkeley) 6/7/85";
#endif

/*
 * printw and friends
 *
 */

# include	"curses.ext"

/*
 *	This routine implements a printf on the standard screen.
 */
printw(fmt, args)
char	*fmt;
int	args; {

	return _sprintw(stdscr, fmt, &args);
}

/*
 *	This routine implements a printf on the given window.
 */
wprintw(win, fmt, args)
WINDOW	*win;
char	*fmt;
int	args; {

	return _sprintw(win, fmt, &args);
}
/*
 *	This routine actually executes the printf and adds it to the window
 *
 *	FGX: upstream faked a V7 FILE and called _doprnt.  FGX's libc has a
 * real va_list printf engine, and fcc's K&R stack ABI makes `&args` in the
 * callers above exactly a va_list (the address of the first variadic slot,
 * with the same 2/4-byte slot layout <stdarg.h> walks).  So hand it to
 * vsprintf.  The buffer is file-scope (curses is single-threaded; keeps the
 * 512 bytes off the 8 KB task stack).
 */
static char	_pwbuf[512];

_sprintw(win, fmt, args)
WINDOW	*win;
char	*fmt;
int	*args; {

	vsprintf(_pwbuf, fmt, (char *)args);
	return waddstr(win, _pwbuf);
}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libcurses (scanw.c, Berkeley 6/7/85 era)
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
static char sccsid[] = "@(#)scanw.c	5.1 (Berkeley) 6/7/85";
#endif

/*
 * scanw and friends
 *
 */

# include	"curses.ext"

/*
 *	This routine implements a scanf on the standard screen.
 */
scanw(fmt, args)
char	*fmt;
int	args; {

	return _sscans(stdscr, fmt, &args);
}
/*
 *	This routine implements a scanf on the given window.
 */
wscanw(win, fmt, args)
WINDOW	*win;
char	*fmt;
int	args; {

	return _sscans(win, fmt, &args);
}
/*
 *	This routine actually executes the scanf from the window.
 *
 *	FGX STUB: upstream faked a V7 FILE and called _doscan; FGX's libc
 * has no scanf engine at all (see docs/userland-bsd-ports.md).  The input
 * line is still read (so the interactive behaviour — echo, line gather —
 * is faithful), but no conversions are performed and ERR is returned.
 * None of the wave-4 BSD games call scanw; revisit if a port needs it.
 */
static char	_swbuf[100];

_sscans(win, fmt, args)
WINDOW	*win;
char	*fmt;
int	*args; {

	if (wgetstr(win, _swbuf) == ERR)
		return ERR;
	return ERR;
}

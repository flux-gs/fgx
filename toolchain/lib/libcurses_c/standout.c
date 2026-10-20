/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libcurses (standout.c, Berkeley 6/7/85 era)
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
static char sccsid[] = "@(#)standout.c	5.1 (Berkeley) 6/7/85";
#endif

/*
 * routines dealing with entering and exiting standout mode
 *
 */

# include	"curses.ext"

/*
 * enter standout mode
 */
char *
wstandout(win)
reg WINDOW	*win;
{
	if (!SO && !UC)
		return FALSE;

	win->_flags |= _STANDOUT;
	return (SO ? SO : UC);
}

/*
 * exit standout mode
 */
char *
wstandend(win)
reg WINDOW	*win;
{
	if (!SO && !UC)
		return FALSE;

	win->_flags &= ~_STANDOUT;
	return (SE ? SE : UC);
}

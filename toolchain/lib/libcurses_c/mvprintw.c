/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libcurses (mvprintw.c, Berkeley 6/7/85 era)
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
static char sccsid[] = "@(#)mvprintw.c	5.1 (Berkeley) 6/7/85";
#endif

# include	"curses.ext"

/*
 * implement the mvprintw commands.  Due to the variable number of
 * arguments, they cannot be macros.  Sigh....
 *
 */

mvprintw(y, x, fmt, args)
reg int		y, x;
char		*fmt;
int		args; {

	return move(y, x) == OK ? _sprintw(stdscr, fmt, &args) : ERR;
}

mvwprintw(win, y, x, fmt, args)
reg WINDOW	*win;
reg int		y, x;
char		*fmt;
int		args; {

	return wmove(win, y, x) == OK ? _sprintw(win, fmt, &args) : ERR;
}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libcurses (scroll.c, Berkeley 6/7/85 era)
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
static char sccsid[] = "@(#)scroll.c	5.1 (Berkeley) 6/7/85";
#endif

# include	"curses.ext"

/*
 *	This routine scrolls the window up a line.
 *
 */
scroll(win)
register  WINDOW	*win;
{
	register int	oy, ox;

# ifdef DEBUG
	fprintf(outf, "SCROLL(%0.2o)\n", win);
# endif

	if (!win->_scroll)
		return ERR;

	getyx(win, oy, ox);
	wmove(win, 0, 0);
	wdeleteln(win);
	wmove(win, oy, ox);

	if (win == curscr) {
		_putchar('\n');
		if (!NONL)
			win->_curx = 0;
# ifdef DEBUG
		fprintf(outf, "SCROLL: win == curscr\n");
# endif
	}
}

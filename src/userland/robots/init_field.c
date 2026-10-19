/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD robots (init_field.c, sccs 5.1, Berkeley 1985)
 *   Ported from src/games/robots (4.3BSD robots as shipped in 2.11BSD).
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
static char sccsid[] = "@(#)init_field.c	5.1 (Berkeley) 5/30/85";
#endif

# include	"robots.h"

/* FGX: hoisted from init_field() — fcc static-LOCAL initializers are
 * int/char literals only; a file-scope static char*[] is supported. */
static char	*desc[] = {
	"Directions:",
	"",
	"y k u",
	" \\|/",
	"h- -l",
	" /|\\",
	"b j n",
	"",
	"Commands:",
	"",
	"w:  wait for end",
	"t:  teleport",
	"q:  quit",
	"^L: redraw screen",
	"",
	"Legend:",
	"",
	"+:  robot",
	"*:  junk heap",
	"@:  you",
	"",
	"Score: 0",
	NULL
};

/*
 * init_field:
 *	Lay down the initial pattern whih is constant across all levels,
 *	and initialize all the global variables.
 */
init_field()
{
	register int	i;
	register WINDOW	*wp;
	register int	j;
	static bool	first = 1;	/* FGX: TRUE expands to (1) — fcc
					 * static-local init wants a bare literal */

	Dead = FALSE;
	Waiting = FALSE;
	stdscr->_flags |= _FLUSH;	/* FGX: flushok(stdscr, TRUE) — the macro's
					 * ternary-of-compound-assign arms don't
					 * parse under fcc yet */
	Score = 0;

	erase();
	move(0, 0);
	addch('+');
	for (i = 1; i < Y_FIELDSIZE; i++) {
		move(i, 0);
		addch('|');
	}
	move(Y_FIELDSIZE, 0);
	addch('+');
	for (i = 1; i < X_FIELDSIZE; i++)
		addch('-');
	addch('+');
	if (first)
		refresh();
	move(0, 1);
	for (i = 1; i < X_FIELDSIZE; i++)
		addch('-');
	addch('+');
	for (i = 1; i < Y_FIELDSIZE; i++) {
		move(i, X_FIELDSIZE);
		addch('|');
	}
	if (first)
		refresh();
	for (i = 0; desc[i] != NULL; i++) {
		move(i, X_FIELDSIZE + 2);
		addstr(desc[i]);
	}
	if (first)
		refresh();
	first = FALSE;
}

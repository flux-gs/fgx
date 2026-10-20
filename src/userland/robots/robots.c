/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD robots (main.c, Berkeley 5/30/85, sccs 5.1)
 *   Ported from src/games/robots (4.3BSD robots as shipped in 2.11BSD).
 *   Original work: Copyright (c) 1980 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * FGX deltas: renamed main.c -> robots.c (the build's main-TU convention);
 * the SIGINT handler is dropped (rob_move.c's case 003 is the quit arm) and
 * the SIGALRM one is installed per-wait in rob_move.c readch() rather than
 * once here, since its handler has to be paired with a live setjmp; setuid/
 * setgid dropped (single-user, no score-file privilege dance); the FANCY
 * pattern_roll/stand_still autoplay stays out (upstream off-by-default).
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if !defined(lint) && !defined(NOSCCS)
static char sccsid[] = "@(#)main.c	5.1 (Berkeley) 5/30/85";
#endif

# include	"robots.h"
# include	<ctype.h>

main(ac, av)
int	ac;
char	**av;
{
	register char	*sp;
	register bool	bad_arg;
	register bool	show_only;
	extern char	*Scorefile;
	extern int	Max_per_uid;

	show_only = FALSE;
	if (ac > 1) {
		bad_arg = FALSE;
		for (++av; ac > 1 && *av[0]; av++, ac--)
			if (av[0][0] != '-')
				if (isdigit(av[0][0]))
					Max_per_uid = atoi(av[0]);
				else {
					Scorefile = av[0];
				}
			else
				for (sp = &av[0][1]; *sp; sp++)
					switch (*sp) {
					  case 's':
						show_only = TRUE;
						break;
					  case 'r':
						Real_time = TRUE;
						break;
					  case 'a':
						Start_level = 4;
						break;
					  case 'j':
						Jump = TRUE;
						break;
					  case 't':
						Teleport = TRUE;
						break;
					  default:
						fprintf(stderr, "robots: uknown option: %c\n", *sp);
						bad_arg = TRUE;
						break;
					}
		if (bad_arg) {
			exit(1);
			/* NOTREACHED */
		}
	}

	if (show_only) {
		show_score();
		exit(0);
		/* NOTREACHED */
	}

	initscr();
	crmode();
	noecho();
	nonl();
	if (LINES != Y_SIZE || COLS != X_SIZE) {
		if (LINES < Y_SIZE || COLS < X_SIZE) {
			endwin();
			printf("Need at least a %dx%d screen\n", Y_SIZE, X_SIZE);
			exit(1);
		}
		delwin(stdscr);
		stdscr = newwin(Y_SIZE, X_SIZE, 0, 0);
	}

	srand(getpid());
	do {
		init_field();
		for (Level = Start_level; !Dead; Level++) {
			make_level();
			play_level();
		}
		move(My_pos.y, My_pos.x);
		printw("AARRrrgghhhh....");
		refresh();
		score();
	} while (another());
	quit();
}

/*
 * quit:
 *	Leave the program elegantly.
 */
quit()
{
	extern int	_putchar();

	mvcur(0, COLS - 1, LINES - 1, 0);
	if (CE) {
		tputs(CE, 1, _putchar);
		endwin();
	}
	else {
		endwin();
		putchar('\n');
	}
	exit(0);
	/* NOTREACHED */
}

/*
 * another:
 *	See if another game is desired
 */
another()
{
	register int	y;

	if (query("Another game?")) {
		if (Full_clear) {
			for (y = 1; y <= Num_scores; y++) {
				move(y, 1);
				clrtoeol();
			}
			refresh();
		}
		return TRUE;
	}
	return FALSE;
}

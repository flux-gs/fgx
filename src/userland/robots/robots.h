/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD robots (robots.h, Berkeley 5/30/85, sccs 5.1)
 *   Ported from src/games/robots (4.3BSD robots as shipped in 2.11BSD).
 *   Original work: Copyright (c) 1980 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * FGX deltas: curses.h by relative path; <stdlib.h>/<string.h> for the
 * rand/memset protos; MAX_PER_UID inlined (was Makefile -D); SCOREFILE
 * moved to /lib (no /usr/games on FGX); the CTRL(X) char-literal macro
 * dropped — K&R cpp substituted macro args inside char literals, fcc/ANSI
 * does not, so users were converted to octal literals at the site.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 *
 *	@(#)robots.h	5.1 (Berkeley) 5/30/85
 */

# include	<curses.h>
# include	<setjmp.h>
# include	<stdlib.h>
# include	<string.h>

/*
 * miscellaneous constants
 */

# define	Y_FIELDSIZE	23
# define	X_FIELDSIZE	60
# define	Y_SIZE		24
# define	X_SIZE		80
# define	MAXLEVELS	4
# define	MAXROBOTS	(MAXLEVELS * 10)
# define	ROB_SCORE	10
# define	S_BONUS		(60 * ROB_SCORE)
# define	Y_SCORE		21
# define	X_SCORE		(X_FIELDSIZE + 9)
# define	Y_PROMPT	(Y_FIELDSIZE - 1)
# define	X_PROMPT	(X_FIELDSIZE + 2)
# define	MAXSCORES	(Y_SIZE - 2)
# define	MAXNAME		16
# define	MS_NAME		"Ten"
# define	SCOREFILE	"/lib/robots.roll"	/* FGX: no /usr/games;
							 * ProDOS name (no _) */
# define	MAX_PER_UID	5			/* FGX: was Makefile -D */

/*
 * characters on screen
 */

# define	ROBOT	'+'
# define	HEAP	'*'
# define	PLAYER	'@'

/*
 * type definitions
 */

typedef struct {
	int	y, x;
} COORD;

/*
 * global variables
 */

extern bool	Dead, Full_clear, Jump, Newscore, Real_time, Running,
		Teleport, Waiting, Was_bonus;

extern char	Cnt_move, Field[Y_FIELDSIZE][X_FIELDSIZE], *Next_move,
		*Move_list, Run_ch;

extern int	Count, Level, Num_robots, Num_scores, Score,
		Start_level, Wait_bonus;

extern COORD	Max, Min, My_pos, Robots[];

extern jmp_buf	End_move;

/*
 * functions types
 */

int	quit(), cmp_sc(), move_robots();

COORD	*rnd_pos();

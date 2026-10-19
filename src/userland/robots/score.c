/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD robots (score.c, Berkeley 5/30/85, sccs 5.1)
 *   Ported from src/games/robots (4.3BSD robots as shipped in 2.11BSD).
 *   Original work: Copyright (c) 1980 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * FGX deltas: set_name's upstream NULL-deref fixed (getpwuid==NULL then
 * wrote through pp; FGX getpwuid returns the single-user entry anyway);
 * show_score's %.*s star-precision -> %.16s (MAXNAME; fcc printf has no
 * star args).  Scorefile lives at /lib/robots_roll (robots.h), staged
 * empty on the disk so scoring works out of the box.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */
#if !defined(lint) && !defined(NOSCCS)
static char sccsid[] = "@(#)score.c	5.1 (Berkeley) 5/30/85";
#endif

# include	"robots.h"

typedef struct {
	int	s_uid;
	int	s_score;
	char	s_name[MAXNAME];
} SCORE;

char	*Scorefile = SCOREFILE;

int	Max_per_uid = MAX_PER_UID;

static SCORE	Top[MAXSCORES];

/*
 * score:
 *	Post the player's score, if reasonable, and then print out the
 *	top list.
 */
score()
{
	register int	inf;
	register SCORE	*scp;
	register int	uid;
	register bool	done_show = FALSE;
	static int	numscores, max_uid;

	Newscore = FALSE;
	if ((inf = open(Scorefile, 2)) < 0) {
		perror(Scorefile);
		return;
	}

	if (read(inf, &max_uid, sizeof max_uid) == sizeof max_uid)
		read(inf, Top, sizeof Top);
	else {
		for (scp = Top; scp < &Top[MAXSCORES]; scp++)
			scp->s_score = -1;
		max_uid = Max_per_uid;
	}

	uid = getuid();
	if (Top[MAXSCORES-1].s_score <= Score) {
		numscores = 0;
		for (scp = Top; scp < &Top[MAXSCORES]; scp++)
			if (scp->s_score < 0 ||
			    (scp->s_uid == uid && ++numscores == max_uid)) {
				if (scp->s_score > Score)
					break;
				scp->s_score = Score;
				scp->s_uid = uid;
				set_name(scp);
				Newscore = TRUE;
				break;
			}
		if (scp == &Top[MAXSCORES]) {
			Top[MAXSCORES-1].s_score = Score;
			Top[MAXSCORES-1].s_uid = uid;
			set_name(&Top[MAXSCORES-1]);
			Newscore = TRUE;
		}
		if (Newscore)
			qsort(Top, MAXSCORES, sizeof(SCORE), cmp_sc);	/* FGX: fcc has no sizeof-on-subscript */
	}

	if (!Newscore) {
		Full_clear = FALSE;
		close(inf);
		return;
	}
	else
		Full_clear = TRUE;

	for (scp = Top; scp < &Top[MAXSCORES]; scp++) {
		if (scp->s_score < 0)
			break;
		move((scp - Top) + 1, 15);
		if (!done_show && scp->s_uid == uid && scp->s_score == Score)
			standout();
		printw(" %d\t%d\t%-8.8s ", (scp - Top) + 1, scp->s_score, scp->s_name);
		if (!done_show && scp->s_uid == uid && scp->s_score == Score) {
			standend();
			done_show = TRUE;
		}
	}
	Num_scores = scp - Top;
	refresh();

	if (Newscore) {
		lseek(inf, 0L, 0);
		write(inf, &max_uid, sizeof max_uid);
		write(inf, Top, sizeof Top);
	}
	close(inf);
}

set_name(scp)
register SCORE	*scp;
{
	/* FGX: single-user, no passwd db — pwd.h's getpwuid is a header-only
	 * stub with no libc implementation yet (upstream also NULL-deref'd on
	 * a missing entry).  Everyone is "fgx". */
	strncpy(scp->s_name, "fgx", MAXNAME);
}

/*
 * cmp_sc:
 *	Compare two scores.
 */
cmp_sc(s1, s2)
register SCORE	*s1, *s2;
{
	return s2->s_score - s1->s_score;
}

/*
 * show_score:
 *	Show the score list for the '-s' option.
 */
show_score()
{
	register SCORE	*scp;
	register int	inf;
	static int	max_score;

	if ((inf = open(Scorefile, 0)) < 0) {
		perror(Scorefile);
		return;
	}

	for (scp = Top; scp < &Top[MAXSCORES]; scp++)
		scp->s_score = -1;

	read(inf, &max_score, sizeof max_score);
	read(inf, Top, sizeof Top);
	close(inf);
	inf = 1;
	for (scp = Top; scp < &Top[MAXSCORES]; scp++)
		if (scp->s_score >= 0)
			printf("%d\t%d\t%.16s\n", inf++, scp->s_score, scp->s_name);	/* FGX: %.*s */
}

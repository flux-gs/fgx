/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD robots (move.c, Berkeley 5/30/85, sccs 5.1)
 *   Ported from src/games/robots (4.3BSD robots as shipped in 2.11BSD).
 *   Original work: Copyright (c) 1980 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * FGX deltas: renamed move.c -> rob_move.c (basename collides with the
 * curses move.c TU in the multi-TU link); readch() wraps the raw getchar()
 * sites so Real_time can put a 3-second alarm behind the read -- upstream's
 * SIGALRM/alarm(3) (main.c:120, move_robs.c:109), with the handler SPLIT
 * because FGX's may not do work (see rt_alarm below); CTRL(L)/CTRL(G) ->
 * octal 014/007 (K&R cpp substituted inside char literals, fcc/ANSI does
 * not); case 003 quits, standing in for upstream's SIGINT handler.
 *
 * Real_time's wait was a pollkey()/ticks() poll loop until apple/fgx#151:
 * pollkey() takes no fd and read the PHYSICAL CONSOLE from whatever terminal
 * the game was on.  The note that justified it -- that FGX had no alarm that
 * could wake a blocked task -- stopped being true when apple/fgx#152 landed.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if !defined(lint) && !defined(NOSCCS)
static char sccsid[] = "@(#)move.c	5.1 (Berkeley) 5/30/85";
#endif

# include	"robots.h"
# include	<ctype.h>
# include	<signal.h>

# define	ESC	'\033'

int  alarm();
int  read();

/*
 * rt_alarm:
 *	The Real_time tick.  It does NOTHING but escape, and both halves of
 * that are required.  A handler may not do work -- its frame carries
 * STKGUARD=0, so move_robots() running under it would recurse into curses on
 * an unguarded stack -- and it may not simply return either, because FGX
 * re-enters a marked syscall unconditionally on signal return (there is no
 * SA_INTERRUPT), which would drop us straight back into the getchar() we were
 * trying to break out of.  longjmp is shallow and abandons the stacked
 * restart, so readch() below does the work at a safe point.
 */
static jmp_buf	Rt_tick;
static char	Rt_ch[1];
static int	Rt_got;		/* the character is already in hand */

static void
rt_alarm(sig)
	int	sig;
{
	longjmp(Rt_tick, 1);
}

/*
 * readch:
 *	Read the next command character.  In Real_time mode the robots take a
 * turn every 3 seconds whether or not the player moved, which is upstream's
 * SIGALRM/alarm(3) (main.c:120, move_robs.c:109) restored: the read BLOCKS on
 * the terminal and the alarm is what ends the wait.
 *
 * IT USED TO POLL THE KEYBOARD RING with pollkey(), which takes no fd and so
 * read the PHYSICAL CONSOLE whatever terminal the game was on (apple/fgx#151);
 * the delta that introduced it said FGX had no working alarm, and apple/fgx#152
 * fixed that.  getchar() reads fd 0 like every other command character here,
 * so Real_time and turn-based mode now take input the same way -- which they
 * did upstream, and which is the whole point.
 *
 * The signal is re-installed each pass.  FGX keeps a caught disposition across
 * delivery, so this is belt and braces, but it is also exactly what upstream
 * does (move_robs.c:40) and it costs one syscall per three seconds.
 *
 * move_robots(TRUE) is called HERE rather than from the handler, where
 * upstream puts it: it walks curses and can longjmp to End_move when the level
 * ends under it, neither of which is safe on an unguarded handler frame.
 *
 * read(2) rather than upstream's getchar() for THIS wait only: it is the call
 * the alarm interrupts, and longjmping out of the middle of getchar() would
 * abandon stdio's own state.  Every other command character here still goes
 * through getchar(), which nothing jumps out of.
 */
static int
readch()
{
	if (!Real_time)
		return getchar();

	for (;;) {
		signal(SIGALRM, rt_alarm);
		Rt_got = 0;
		if (setjmp(Rt_tick) == 0) {
			alarm(3);
			if (read(0, Rt_ch, 1) == 1)
				Rt_got = 1;
			alarm(0);
		}
		/* Rt_got IS THE RACE GUARD.  The alarm can fire in the window
		 * between the read completing and alarm(0) cancelling it, and
		 * the handler's longjmp would then throw away a keystroke the
		 * player had already typed.  Deciding here, on both paths, is
		 * what makes that window harmless: if the character arrived it
		 * is used whichever way we got here.  It lives in a static
		 * because a local would be a register variable, and longjmp
		 * does not promise those survive. */
		if (Rt_got)
			return Rt_ch[0] & 0177;
		move_robots(TRUE);	/* the 3 seconds ran out */
	}
}

/*
 * get_move:
 *	Get and execute a move from the player
 */
get_move()
{
	register int	c;
	register int	y, x, lastmove;
	static COORD	newpos;

	if (Waiting)
		return;

	for (;;) {
		if (Teleport && must_telep())
			goto teleport;
		if (Running)
			c = Run_ch;
		else if (Count != 0)
			c = Cnt_move;
		else {
over:
			c = readch();
			if (isdigit(c)) {
				Count = (c - '0');
				while (isdigit(c = readch()))
					Count = Count * 10 + (c - '0');
				if (c == ESC)
					goto over;
				Cnt_move = c;
				if (Count)
					leaveok(stdscr, TRUE);
			}
		}

		switch (c) {
		  case ' ':
		  case '.':
			if (do_move(0, 0))
				goto ret;
			break;
		  case 'y':
			if (do_move(-1, -1))
				goto ret;
			break;
		  case 'k':
			if (do_move(-1, 0))
				goto ret;
			break;
		  case 'u':
			if (do_move(-1, 1))
				goto ret;
			break;
		  case 'h':
			if (do_move(0, -1))
				goto ret;
			break;
		  case 'l':
			if (do_move(0, 1))
				goto ret;
			break;
		  case 'b':
			if (do_move(1, -1))
				goto ret;
			break;
		  case 'j':
			if (do_move(1, 0))
				goto ret;
			break;
		  case 'n':
			if (do_move(1, 1))
				goto ret;
			break;
		  case 'Y': case 'U': case 'H': case 'J':
		  case 'K': case 'L': case 'B': case 'N':
		  case '>':
			Running = TRUE;
			if (c == '>')
				Run_ch = ' ';
			else
				Run_ch = tolower(c);
			leaveok(stdscr, TRUE);
			break;
		  case 'q':
		  case 'Q':
			if (query("Really quit?"))
				quit();
			refresh();
			break;
		  case 003:			/* FGX: ^C, was SIGINT */
			quit();
			break;
		  case 'w':
		  case 'W':
			Waiting = TRUE;
			leaveok(stdscr, TRUE);
			stdscr->_flags &= ~_FLUSH;	/* FGX: flushok(stdscr, FALSE) */
			goto ret;
		  case 't':
		  case 'T':
teleport:
			Running = FALSE;
			mvaddch(My_pos.y, My_pos.x, ' ');
			My_pos = *rnd_pos();
			mvaddch(My_pos.y, My_pos.x, PLAYER);
			leaveok(stdscr, FALSE);
			refresh();
			flush_in();
			goto ret;
		  case 014:			/* FGX: CTRL(L) */
			wrefresh(curscr);
			break;
		  case EOF:
			break;
		  default:
			putchar(007);		/* FGX: CTRL(G) */
			reset_count();
			fflush(stdout);
			break;
		}
	}
ret:
	if (Count > 0)
		if (--Count == 0)
			leaveok(stdscr, FALSE);
}

/*
 * must_telep:
 *	Must I teleport; i.e., is there anywhere I can move without
 * being eaten?
 */
must_telep()
{
	register int	x, y;
	static COORD	newpos;

	for (y = -1; y <= 1; y++) {
		newpos.y = My_pos.y + y;
		if (newpos.y <= 0 || newpos.y >= Y_FIELDSIZE)
			continue;
		for (x = -1; x <= 1; x++) {
			newpos.x = My_pos.x + x;
			if (newpos.x <= 0 || newpos.x >= X_FIELDSIZE)
				continue;
			if (Field[newpos.y][newpos.x] > 0)
				continue;
			if (!eaten(&newpos))
				return FALSE;
		}
	}
	return TRUE;
}

/*
 * do_move:
 *	Execute a move
 */
do_move(dy, dx)
int	dy, dx;
{
	static COORD	newpos;

	newpos.y = My_pos.y + dy;
	newpos.x = My_pos.x + dx;
	if (newpos.y <= 0 || newpos.y >= Y_FIELDSIZE ||
	    newpos.x <= 0 || newpos.x >= X_FIELDSIZE ||
	    Field[newpos.y][newpos.x] > 0 || eaten(&newpos)) {
		if (Running) {
			Running = FALSE;
			leaveok(stdscr, FALSE);
			move(My_pos.y, My_pos.x);
			refresh();
		}
		else {
			putchar(007);	/* FGX: CTRL(G) */
			reset_count();
		}
		return FALSE;
	}
	else if (dy == 0 && dx == 0)
		return TRUE;
	mvaddch(My_pos.y, My_pos.x, ' ');
	My_pos = newpos;
	mvaddch(My_pos.y, My_pos.x, PLAYER);
	if (!jumping())
		refresh();
	return TRUE;
}

/*
 * eaten:
 *	Player would get eaten at this place
 */
eaten(pos)
register COORD	*pos;
{
	register int	x, y;

	for (y = pos->y - 1; y <= pos->y + 1; y++) {
		if (y <= 0 || y >= Y_FIELDSIZE)
			continue;
		for (x = pos->x - 1; x <= pos->x + 1; x++) {
			if (x <= 0 || x >= X_FIELDSIZE)
				continue;
			if (Field[y][x] == 1)
				return TRUE;
		}
	}
	return FALSE;
}

/*
 * reset_count:
 *	Reset the count variables
 */
reset_count()
{
	Count = 0;
	Running = FALSE;
	leaveok(stdscr, FALSE);
	refresh();
}

/*
 * jumping:
 *	See if we are jumping, i.e., we should not refresh.
 */
jumping()
{
	return (Jump && (Count || Running || Waiting));
}

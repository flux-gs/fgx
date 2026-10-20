/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD worm (worm.c, Berkeley 6/25/85, sccs 5.2)
 *   Ported from src/games/worm.c (4.3BSD worm as shipped in 2.11BSD).
 *   Original work: Copyright (c) 1980 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * FGX deltas (each marked at the site):
 *   - SIGALRM/alarm(2) idle timer RESTORED (apple/fgx#151).  It had been a
 *     pollkey()/ticks() poll loop, because alarm(2) could not wake a blocked
 *     task -- apple/fgx#152 fixed that -- and pollkey() takes no fd, so worm
 *     read the PHYSICAL CONSOLE from whatever terminal it was on.  wake() is
 *     back, split: the handler only escapes, the loop does the move.
 *   - SIGTSTP/suspend() dropped (no job control).  SIGINT/SIGTERM are CAUGHT
 *     and quit through leave(), which is upstream's signal(SIGINT, leave);
 *     the read now goes through the cbreak line discipline, where ^C is a
 *     signal rather than the character the old ring read delivered.  SIGQUIT
 *     is not catchable on FGX (see signal.h), so SIGTERM stands in.
 *   - CNTRL(p) expanded to octal literals: K&R cpp substituted macro args
 *     inside char literals ('p'-'A'+1); ANSI-style cpp (fcc) does not.
 *   - setbuf/outbuf dropped (no setbuf in FGX stdio; output is unbuffered).
 *   - baudrate()/B1200 "slow tty" test dropped: the SHR console is
 *     memory-mapped (slow = 0 always).
 *   - sleep(2) -> nanosleep(120) (60 Hz ticks).
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if !defined(lint) && !defined(NOSCCS)
static char sccsid[] = "@(#)worm.c	5.2 (Berkeley) 6/25/85";
#endif

/*
 * Worm.  Written by Michael Toy
 * UCSC
 */

#include <ctype.h>
#include <stdlib.h>
#include <curses.h>

#define newlink() (struct body *) malloc(sizeof (struct body));
#define HEAD '@'
#define BODY 'o'
#define LENGTH 7
#define RUNLEN 8
#define when break;case
#define otherwise break;default

#include <setjmp.h>
#include <signal.h>

/* FGX: tty primitives (libc pile / libc.s; no header). */
int  nanosleep();
int  getpid();
int  alarm();
int  read();
int  leave();		/* defined below; the quit path calls it from main() */

/*
 * The idle tick and the quit key.  BOTH HANDLERS ONLY ESCAPE, and both halves
 * of that are required.  A handler may not do work -- its frame carries
 * STKGUARD=0, so process() or leave() running under one would walk curses on
 * an unguarded stack -- and it may not simply return either, because FGX
 * re-enters a marked syscall unconditionally on signal return (there is no
 * SA_INTERRUPT), which would drop us straight back into the read() we were
 * trying to end.  longjmp is shallow and abandons the stacked restart; the
 * loop below does the work at a safe point, which is where upstream's wake()
 * and leave() effectively run anyway.
 */
static jmp_buf	Wjb;
static int	Wwhy;		/* 1 = the second ran out, 2 = quit */
static int	Wgot;		/* the character is already in hand */
static char	Wch[1];		/* read(2) needs a char, `ch' is an int */

static void
wake(sig)
	int	sig;
{
	Wwhy = 1;
	longjmp(Wjb, 1);
}

static void
onquit(sig)
	int	sig;
{
	Wwhy = 2;
	longjmp(Wjb, 1);
}

WINDOW *tv;
WINDOW *stw;
struct body {
	int x;
	int y;
	struct body *prev;
	struct body *next;
} *head, *tail, goody;
int growing = 0;
int running = 0;
int score = 0;
int start_len = LENGTH;
char lastch;

main(argc, argv)
int argc;
char **argv;
{
	if (argc == 2)
		start_len = atoi(argv[1]);
	if ((start_len <= 0) || (start_len > 500))
		start_len = LENGTH;
	srand(getpid());
	initscr();
	crmode();
	noecho();
	clear();
	stw = newwin(1, COLS-1, 0, 0);
	tv = newwin(LINES-1, COLS-1, 1, 0);
	box(tv, '*', '*');
	scrollok(tv, FALSE);
	scrollok(stw, FALSE);
	wmove(stw, 0, 0);
	wprintw(stw, " Worm");
	refresh();
	wrefresh(stw);
	wrefresh(tv);
	life();			/* Create the worm */
	prize();		/* Put up a goal */
	while(1)
	{
		if (running)
		{
			running--;
			process(lastch);
		}
		else
		{
			/* Upstream's shape: block in read(2) on the terminal
			 * with a one-second SIGALRM behind it, so a player who
			 * touches nothing still moves.  The signals are
			 * re-installed each pass -- FGX keeps a caught
			 * disposition across delivery, so it is belt and
			 * braces, but it is also what upstream's wake() does. */
			fflush(stdout);
			signal(SIGALRM, wake);
			signal(SIGINT, onquit);
			signal(SIGTERM, onquit);
			Wwhy = 0;
			Wgot = 0;
			if (setjmp(Wjb) == 0) {
				alarm(1);
				if (read(0, Wch, 1) == 1)
					Wgot = 1;
				alarm(0);
			}
			/* Wgot IS THE RACE GUARD.  The alarm can fire in the
			 * window between the read completing and alarm(0)
			 * cancelling it, and the handler's longjmp would then
			 * discard a key the player had already pressed -- at a
			 * one-second cadence that is not a rare window.
			 * Deciding here, after both paths converge, makes it
			 * harmless.  Statics because longjmp does not promise
			 * locals survive. */
			if (Wwhy == 2)
				leave();		/* ^C: endwin, exit */
			else if (Wgot)
				process(Wch[0] & 0177);
			else
				process(lastch);	/* upstream's wake() */
		}
	}
}

life()
{
	reg struct body *bp, *np;
	reg int i;

	head = newlink();
	head->x = start_len+2;
	head->y = 12;
	head->next = NULL;
	display(head, HEAD);
	for (i = 0, bp = head; i < start_len; i++, bp = np) {
		np = newlink();
		np->next = bp;
		bp->prev = np;
		np->x = bp->x - 1;
		np->y = bp->y;
		display(np, BODY);
	}
	tail = np;
	tail->prev = NULL;
}

display(pos, chr)
struct body *pos;
int chr;
{
	wmove(tv, pos->y, pos->x);
	waddch(tv, chr);
}

leave()
{
	endwin();
	exit(0);
}

rnd(range)
int range;
{
	return abs((rand()>>5)+(rand()>>5)) % range;
}

newpos(bp)
struct body * bp;
{
	do {
		bp->y = rnd(LINES-3)+ 2;
		bp->x = rnd(COLS-3) + 1;
		wmove(tv, bp->y, bp->x);
	} while(winch(tv) != ' ');
}

prize()
{
	int value;

	value = rnd(9) + 1;
	newpos(&goody);
	waddch(tv, value+'0');
	wrefresh(tv);
}

process(ch)
int ch;
{
	reg int x,y;
	struct body *nh;

	x = head->x;
	y = head->y;
	switch(ch)
	{
		when 'h': x--;
		when 'j': y++;
		when 'k': y--;
		when 'l': x++;
		when 'H': x--; running = RUNLEN; ch = tolower(ch);
		when 'J': y++; running = RUNLEN/2; ch = tolower(ch);
		when 'K': y--; running = RUNLEN/2; ch = tolower(ch);
		when 'L': x++; running = RUNLEN; ch = tolower(ch);
		when '\f': setup(); return;
		when 003: crash(); return;	/* FGX: CNTRL(C) */
		when 004: crash(); return;	/* FGX: CNTRL(D) */
		otherwise: return;		/* FGX: idle re-arm is the poll loop */
	}
	lastch = ch;
	if (growing == 0)
	{
		display(tail, ' ');
		tail->next->prev = NULL;
		nh = tail->next;
		free(tail);
		tail = nh;
	}
	else growing--;
	display(head, BODY);
	wmove(tv, y, x);
	if (isdigit(ch = winch(tv)))
	{
		growing += ch-'0';
		prize();
		score += growing;
		running = 0;
		wmove(stw, 0, 68);
		wprintw(stw, "Score: %3d", score);
		wrefresh(stw);
	}
	else if(ch != ' ') crash();
	nh = newlink();
	nh->next = NULL;
	nh->prev = head;
	head->next = nh;
	nh->y = y;
	nh->x = x;
	display(nh, HEAD);
	head = nh;
	wrefresh(tv);
}

crash()
{
	nanosleep(120);		/* FGX: sleep(2) — 60 Hz ticks */
	clear();
	move(23, 0);
	refresh();
	printf("Well you ran into something and the game is over.\n");
	printf("Your final score was %d\n", score);
	leave();
}

setup()
{
	clear();
	refresh();
	touchwin(stw);
	wrefresh(stw);
	touchwin(tv);
	wrefresh(tv);
}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libcurses (getch.c, Berkeley 6/7/85 era); keypad
 *   mode after NetBSD 1.5 lib/libcurses/getch.c (inkey), Brett Lymn.
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
static char sccsid[] = "@(#)getch.c	5.3 (Berkeley) 4/16/86";
#endif

# include	"curses.ext"
# include	<sys/types.h>
# include	<sys/time.h>

/*
 * KEYPAD MODE, after NetBSD 1.5 lib/libcurses/getch.c (inkey()).  A key
 * whose termcap sequence (ku kd kl kr kh k0-k9, read by setterm into KU..K9)
 * arrives whole returns its KEY_ value.  Bytes that start a sequence but do
 * not finish one before the inter-key delay, or that stop matching, come
 * back one at a time, the first now and the rest on the following calls,
 * matched again from the start as NetBSD's INKEY_BACKOUT state does.  So a
 * lone ESC is ESC.
 *
 * Two departures from NetBSD.  The sequences are matched against a table
 * of the 4.3BSD globals rather than a keymap tree: there are at most
 * fifteen and the console sends three bytes for each.  And the delay is a
 * select(2) on the terminal, not termios VMIN/VTIME, which 2.11BSD's tty
 * does not have; DELAY is NetBSD's DEFAULT_DELAY of two tenths.
 */
# define	KBUFSZ	8
# define	NKEYS	15
# define	DELAY	200000L		/* microseconds */

static int	_kbuf[KBUFSZ];		/* bytes read but not yet returned */
static int	_kn;

static char *
_kseq(i)
int	i;
{
	switch (i) {
	case 0:	return KU;
	case 1:	return KD;
	case 2:	return KL;
	case 3:	return KR;
	case 4:	return KH;
	case 5:	return K0;
	case 6:	return K1;
	case 7:	return K2;
	case 8:	return K3;
	case 9:	return K4;
	case 10: return K5;
	case 11: return K6;
	case 12: return K7;
	case 13: return K8;
	}
	return K9;
}

static int
_kval(i)
int	i;
{
	switch (i) {
	case 0:	return KEY_UP;
	case 1:	return KEY_DOWN;
	case 2:	return KEY_LEFT;
	case 3:	return KEY_RIGHT;
	case 4:	return KEY_HOME;
	}
	return KEY_F(i - 5);
}

/*
 * The next byte: the backlog first, then the terminal.  With to set, wait
 * at most DELAY for it and return -1 if none comes.
 */
static int
_knext(to)
int	to;
{
	reg int	i, c;
	fd_set		fds;
	struct timeval	tv;

	if (_kn > 0) {
		c = _kbuf[0];
		for (i = 1; i < _kn; i++)
			_kbuf[i - 1] = _kbuf[i];
		_kn--;
		return c;
	}
	if (to && stdin->_cnt <= 0) {
		FD_ZERO(&fds);
		FD_SET(fileno(stdin), &fds);
		tv.tv_sec = 0;
		tv.tv_usec = DELAY;
		if (select(fileno(stdin) + 1, &fds, (fd_set *)0, (fd_set *)0,
		    &tv) <= 0)
			return -1;
	}
	return getchar() & 0377;
}

/*
 * Return seq[1..n-1] to the front of the backlog, ahead of anything still
 * queued behind them.
 */
static
_kunread(seq, n)
int	*seq;
int	n;
{
	reg int	i;

	for (i = _kn - 1; i >= 0; i--)
		if (i + n - 1 < KBUFSZ)
			_kbuf[i + n - 1] = _kbuf[i];
	for (i = 1; i < n; i++)
		_kbuf[i - 1] = seq[i];
	_kn += n - 1;
	if (_kn > KBUFSZ)
		_kn = KBUFSZ;
}

static int
_inkey()
{
	int		seq[KBUFSZ];
	reg int		n, i, j, part;
	reg char	*s;
	int		c;

	n = 0;
	seq[n++] = _knext(0);
	for (;;) {
		part = 0;
		for (i = 0; i < NKEYS; i++) {
			s = _kseq(i);
			if (s == 0 || *s == 0)
				continue;
			for (j = 0; j < n && s[j] != 0; j++)
				if ((s[j] & 0377) != seq[j])
					break;
			if (j < n)
				continue;		/* differs, or is shorter */
			if (s[n] == 0)
				return _kval(i);	/* the whole sequence */
			part = 1;			/* a prefix so far */
		}
		if (!part || n == KBUFSZ ||
		    (c = _knext(1)) < 0) {
			_kunread(seq, n);
			return seq[0];
		}
		seq[n++] = c;
	}
}

/*
 *	This routine reads in a character from the window.
 *
 */
wgetch(win)
reg WINDOW	*win; {

	reg bool	weset = FALSE;
	reg int		inp;

	if (!win->_scroll && (win->_flags&_FULLWIN)
	    && win->_curx == win->_maxx - 1 && win->_cury == win->_maxy - 1)
		return ERR;
# ifdef DEBUG
	fprintf(outf, "WGETCH: _echoit = %c, _rawmode = %c\n", _echoit ? 'T' : 'F', _rawmode ? 'T' : 'F');
# endif
	if (_echoit && !_rawmode) {
		cbreak();
		weset++;
	}
	if (win->_flags & _KEYPAD)
		inp = _inkey();
	else
		inp = getchar();
# ifdef DEBUG
	fprintf(outf,"WGETCH got '%s'\n",unctrl(inp));
# endif
	if (_echoit && inp < KEY_MIN) {
		mvwaddch(curscr, win->_cury + win->_begy,
			win->_curx + win->_begx, inp);
		waddch(win, inp);
	}
	if (weset)
		nocbreak();
	return inp;
}

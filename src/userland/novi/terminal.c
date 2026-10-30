/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) Dave Plummer
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: novi (davepl/pdpsrc, bsd/novi)
 *   Ported from novi, a nano-like editor for split-I/D 2.11BSD on the PDP-11.
 *   Upstream: https://github.com/davepl/pdpsrc (bsd/novi), commit 381ac12.
 *
 *   LICENSE: BSD-2-Clause, in its author's words.  davepl/pdpsrc carries
 *   no LICENSE file and novi's sources no copyright header; asked, the
 *   author answered "you can assume NOVI is under the 2_BSD license"
 *   (2026-10-29).  See docs/PROVENANCE.md.
 *
 * terminal.c -- raw mode, key decoding, cursor motion.
 *
 * FGX takes the SGTTY branch, unchanged from the PDP-11's: the FGX console
 * line discipline acts on ECHO/CBREAK/RAW in struct sgttyb exactly as 2.11BSD
 * does.  Only the branch CONDITION moved -- __FGX__ is predefined by fcc.
 *
 * The ANSI output vocabulary needs no adaptation.  FGX's console carries a
 * real VT handler (src/kernel/far/console/console_vthandler.s): DECTCEM
 * (?25, cursor hide), the ?1049 alternate screen, DECAWM, CUP, ED/EL and SGR
 * are all implemented, and cursor keys arrive kernel-wide as vt100 escape
 * sequences, which is exactly what term_key() decodes.
 *
 * KNOWN INTERACTION: novi asks for RAW, in which BSD generates no signals, and
 * binds ^C to its own "where am I" command.  FGX's console currently raises
 * INTR regardless of RAW (apple/fgx#57), so ^C reaches the SIGINT handler and
 * novi exits instead of reporting the position.  That is #57's bug, not a
 * port delta -- the code here is upstream's and becomes correct when #57 does.
 */
#include <sys/types.h>
#include <sys/ioctl.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include "terminal.h"

#if defined(pdp11) || defined(__pdp11__) || defined(__FGX__)
#define NOVI_SGTTY 1
#endif

#ifdef NOVI_SGTTY
#include <sgtty.h>
static struct sgttyb saved_tty;
#else
#include <termios.h>
static struct termios saved_tty;
#endif

static int opened;

int
term_open(void)
{
#ifdef NOVI_SGTTY
	struct sgttyb t;

	if (gtty(0, &saved_tty) < 0)
		return -1;
	t = saved_tty;
	t.sg_flags &= ~(ECHO | CRMOD);
	t.sg_flags |= RAW;
	if (stty(0, &t) < 0)
		return -1;
#else
	struct termios t;

	if (tcgetattr(0, &saved_tty) < 0)
		return -1;
	t = saved_tty;
	t.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
	t.c_oflag &= ~(OPOST);
	t.c_cflag |= CS8;
	t.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
	t.c_cc[VMIN] = 1;
	t.c_cc[VTIME] = 0;
	if (tcsetattr(0, TCSAFLUSH, &t) < 0)
		return -1;
#endif
	opened = 1;
	term_dirty();                   /* alternate screen: nothing on it yet */
	term_put("\033[?1049h\033[?25l");
	return 0;
}

void
term_close(void)
{
	if (!opened)
		return;
	term_put("\033[?25h\033[0m\033[H\033[J\033[?1049l");
#ifdef NOVI_SGTTY
	(void)stty(0, &saved_tty);
#else
	(void)tcsetattr(0, TCSAFLUSH, &saved_tty);
#endif
	opened = 0;
}

void
term_size(int *rows, int *cols)
{
#ifdef TIOCGWINSZ
	struct winsize w;

	if (ioctl(1, TIOCGWINSZ, (char *)&w) == 0 && w.ws_row && w.ws_col) {
		*rows = w.ws_row;
		*cols = w.ws_col;
		return;
	}
#endif
	*rows = 24;
	*cols = 80;
}

void
term_write(char *s, int n)
{
	int done;
	int k;

	done = 0;
	while (done < n) {
		k = write(1, s + done, n - done);
		if (k <= 0)
			return;
		done += k;
	}
}

void
term_put(char *s)
{
	term_write(s, strlen(s));
}

/* FGX addition: a shadow of what is on the screen, so a redraw emits only the
 * cells that actually changed.
 *
 * novi redraws the WHOLE screen after every keystroke -- upstream's model, and
 * on a serial terminal a perfectly reasonable one.  Here it is ~2 KB pushed
 * through the console's VT parser and repainted into SHR for a change of one
 * character, which is visible as the entire display flickering under the
 * cursor.  Measured at 32% of a keystroke once the buffer-walk costs were
 * fixed (they used to dwarf it).
 *
 * term_row() takes a whole row of already-rendered cells, compares it with
 * what that row last held, and writes only the span between the first and
 * last differing column -- nothing at all for an unchanged row, which is
 * every row but one when typing. */
#define TERM_MAXROWS 32
#define TERM_MAXCOLS 160

static char shadow[TERM_MAXROWS][TERM_MAXCOLS];
static char shadow_inv[TERM_MAXROWS];
static char shadow_len[TERM_MAXROWS];   /* 0 = never drawn */

/* Anything that moves the screen out from under the shadow -- a clear, an
 * alternate-screen switch, a resize -- must say so, or the next redraw will
 * "skip" rows that are no longer there. */
void
term_dirty(void)
{
	int r;

	for (r = 0; r < TERM_MAXROWS; ++r)
		shadow_len[r] = 0;
}

void
term_row(int row, char *cells, int n, int inverse)
{
	char *sh;
	int first;
	int last;
	int i;

	if (row < 0 || row >= TERM_MAXROWS || n <= 0 || n > TERM_MAXCOLS) {
		term_move(row, 0);              /* outside the shadow: as before */
		if (inverse)
			term_put("\033[7m");
		term_write(cells, n);
		if (inverse)
			term_put("\033[0m");
		return;
	}
	sh = shadow[row];
	if (shadow_len[row] == (char)n && shadow_inv[row] == (char)inverse) {
		first = -1;
		for (i = 0; i < n; ++i) {
			if (sh[i] != cells[i]) {
				first = i;
				break;
			}
		}
		if (first < 0)
			return;                 /* identical: emit nothing */
		last = first;
		for (i = n - 1; i > first; --i) {
			if (sh[i] != cells[i]) {
				last = i;
				break;
			}
		}
	} else {
		first = 0;
		last = n - 1;
	}
	term_move(row, first);
	if (inverse)
		term_put("\033[7m");
	term_write(cells + first, last - first + 1);
	if (inverse)
		term_put("\033[0m");
	for (i = first; i <= last; ++i)
		sh[i] = cells[i];
	shadow_len[row] = (char)n;
	shadow_inv[row] = (char)inverse;
}

void
term_move(int row, int col)
{
	char seq[32];

	(void)sprintf(seq, "\033[%d;%dH", row + 1, col + 1);
	term_put(seq);
}

void
term_clear(void)
{
	term_put("\033[H\033[J");
	term_dirty();                   /* the screen is no longer what we think */
}

static int
readone(void)
{
	unsigned char c;

	if (read(0, (char *)&c, 1) != 1)
		return -1;
	return c;
}

int
term_key(void)
{
	int a;
	int b;
	int c;
	int final;

	a = readone();
	if (a == 27) {
		b = readone();
		if (b != '[' && b != 'O')
			return 27;
	} else if (a == 0233) {
		b = '[';
	} else {
		return a;
	}
	c = readone();
	if (c == 'A') return KEY_UP;
	if (c == 'B') return KEY_DOWN;
	if (c == 'C') return KEY_RIGHT;
	if (c == 'D') return KEY_LEFT;
	if (c == 'H') return KEY_HOME;
	if (c == 'F') return KEY_END;
	if (b == '[' && c == 'I') return KEY_PGUP;
	if (b == '[' && c == 'G') return KEY_PGDN;
	if (c >= '0' && c <= '9') {
		a = c - '0';
		c = readone();
		while (c >= '0' && c <= '9') {
			a = a * 10 + c - '0';
			c = readone();
		}
		final = c;
		while (final >= 0 && final < 0100)
			final = readone();
		if (final == 'A') return KEY_UP;
		if (final == 'B') return KEY_DOWN;
		if (final == 'C') return KEY_RIGHT;
		if (final == 'D') return KEY_LEFT;
		if (final == 'H') return KEY_HOME;
		if (final == 'F') return KEY_END;
		if (final == '~' || final == '^' || final == '$' || final == '@') {
			if (a == 1 || a == 7) return KEY_HOME;
			if (a == 2) return KEY_INSERT;
			if (a == 3) return KEY_DELETE;
			if (a == 4 || a == 8) return KEY_END;
			if (a == 5) return KEY_PGUP;
			if (a == 6) return KEY_PGDN;
		}
	}
	return 27;
}

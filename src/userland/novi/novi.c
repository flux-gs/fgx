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
 * novi(1) -- a small full-screen editor that never holds the document in
 * memory.  Two scratch files form a gap at the cursor: text before it in one,
 * text after it REVERSED in the other, so editing and cursor motion cost
 * bounded memory whatever the file size.  That is what makes it fit FGX,
 * where a task's data lives in a single 64 KB bank.
 *
 * The FGX deltas are in buffer.c/buffer.h (no per-keystroke ftruncate, the
 * bulk read) and terminal.c (the sgtty branch, the screen shadow).  Here the
 * redraw scans and pulls each line in bulk rather than a character at a
 * time.  do_cut is upstream's, ftruncate and all -- FGX grew ftruncate(2) for
 * this port (apple/fgx#67).
 */
#include <sys/types.h>
#include <sys/file.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include "buffer.h"
#include "terminal.h"

#define MAXNAME 255
#define MAXCOLS 160
#define CTRL(c) ((c) & 037)

struct editor {
	struct buffer text;
	char name[MAXNAME + 1];
	off_t top;
	int hscroll;
	int rows;
	int cols;
	int wanted;
	int cutfd;
	int cutappend;
	int overwrite;
	char message[MAXCOLS + 1];
};

static struct editor E;

static off_t line_start(struct buffer *b, off_t p);
static off_t line_end(struct buffer *b, off_t p);
static off_t next_line(struct buffer *b, off_t p);
static int visual_col(struct buffer *b, off_t p);
static off_t draw_line(int row, off_t start);
static void refresh(void);

static int
on_line(off_t cur, off_t start, off_t next)
{
	off_t n;

	n = buf_size(&E.text);
	return cur >= start && (cur < next ||
	    (cur == n && line_end(&E.text, start) == n));
}

static void
die(int sig)
{
	term_close();
	buf_close(&E.text);
	if (E.cutfd >= 0)
		(void)close(E.cutfd);
	if (sig)
		_exit(1);
}

static void
message(char *s)
{
	(void)strncpy(E.message, s, MAXCOLS);
	E.message[MAXCOLS] = '\0';
}

static off_t
line_start(struct buffer *b, off_t p)
{
	while (p > 0 && buf_get(b, p - 1) != '\n')
		--p;
	return p;
}

static off_t
line_end(struct buffer *b, off_t p)
{
	char raw[BUF_CACHE];
	off_t n;
	int got;
	int i;

	/* FGX: scan in bulk.  Upstream's per-character buf_get walk over the
	 * whole visible page cost 40% of a redraw -- see buf_read in buffer.c
	 * for why one character is so expensive here. */
	n = buf_size(b);
	while (p < n) {
		got = buf_read(b, p, raw, sizeof raw);
		if (got <= 0)
			break;
		for (i = 0; i < got; ++i) {
			if (raw[i] == '\n')
				return p + i;
		}
		p += got;
	}
	return p < n ? p : n;
}

static off_t
next_line(struct buffer *b, off_t p)
{
	off_t q;

	q = line_end(b, p);
	if (q < buf_size(b))
		++q;
	return q;
}

static int
visual_col(struct buffer *b, off_t p)
{
	off_t q;
	int col;
	int ch;

	q = line_start(b, p);
	col = 0;
	while (q < p) {
		ch = buf_get(b, q++);
		if (ch == '\t')
			col = (col + 8) & ~7;
		else if (ch != '\n')
			++col;
	}
	return col;
}

static off_t
at_column(struct buffer *b, off_t start, int want)
{
	off_t p;
	off_t n;
	int col;
	int next;
	int ch;

	p = start;
	n = buf_size(b);
	col = 0;
	while (p < n && (ch = buf_get(b, p)) != '\n') {
		next = ch == '\t' ? (col + 8) & ~7 : col + 1;
		if (next > want)
			break;
		col = next;
		++p;
	}
	return p;
}

static void
put_padded(int row, char *s, int inverse)
{
	char out[MAXCOLS];
	int width;
	int n;

	width = E.cols > MAXCOLS ? MAXCOLS : E.cols;
	n = strlen(s);
	if (n > width)
		n = width;
	(void)memcpy(out, s, n);
	while (n < width)
		out[n++] = ' ';
	term_row(row, out, width, inverse);
}

static int
body_rows(void)
{
	return E.rows > 6 ? E.rows - 4 : E.rows - 2;
}

static void
ensure_visible(void)
{
	off_t cur;
	off_t p;
	off_t q;
	int body;
	int i;
	int col;

	cur = buf_pos(&E.text);
	body = body_rows();
	if (E.top > cur)
		E.top = line_start(&E.text, cur);
	p = E.top;
	for (i = 0; i < body && p <= buf_size(&E.text); ++i) {
		q = next_line(&E.text, p);
		if (on_line(cur, p, q))
			break;
		if (q == p)
			break;
		p = q;
	}
	while (i >= body) {
		E.top = next_line(&E.text, E.top);
		p = E.top;
		for (i = 0; i < body && p <= buf_size(&E.text); ++i) {
			q = next_line(&E.text, p);
			if (on_line(cur, p, q))
				break;
			p = q;
		}
	}
	col = visual_col(&E.text, cur);
	if (col < E.hscroll)
		E.hscroll = col;
	if (col >= E.hscroll + E.cols)
		E.hscroll = col - E.cols + 1;
}

static off_t
draw_line(int row, off_t start)
{
	static char out[MAXCOLS];
	static char raw[BUF_CACHE];
	off_t p;
	off_t n;
	int width;
	int col;
	int used;
	int ch;
	int count;
	int need;
	int got;
	int done;
	int i;
	int hs;
	int lim;

	width = E.cols > MAXCOLS ? MAXCOLS : E.cols;
	for (used = 0; used < width; ++used)
		out[used] = ' ';
	p = start;
	n = buf_size(&E.text);
	col = 0;
	/* FGX: pull the line in bulk instead of one buf_get per character (see
	 * buf_read).  A row needs at most hscroll + width BYTES however the
	 * tabs expand, because a tab is one byte. */
	hs = E.hscroll;
	lim = hs + width;
	need = E.hscroll + width;
	if (need > (int)sizeof raw)
		need = (int)sizeof raw;
	done = 0;
	while (!done && p < n) {
		got = buf_read(&E.text, p, raw, need);
		if (got <= 0)
			break;
		p += got;
		for (i = 0; i < got; ++i) {
			ch = (unsigned char)raw[i];
			if (ch == '\n') {
				done = 1;
				break;
			}
			count = 1;
			if (ch == '\t') {
				count = 8 - (col & 7);
				ch = ' ';
			} else if (ch < 32 || ch == 127)
				ch = '?';
			/* The translation is hoisted out of the expansion
			 * loop, and the window bounds out of the whole
			 * function: fcc reloads a global struct field on
			 * every mention, and this runs once per COLUMN of
			 * the screen. */
			while (count-- > 0) {
				if (col >= hs && col < lim)
					out[col - hs] = ch;
				++col;
			}
			if (col >= lim) {
				/* Row is full but the line runs on: the caller
				 * still needs where the NEXT line starts, so
				 * finish the scan without rendering. */
				p = line_end(&E.text, p - got + i);
				done = 2;
				break;
			}
		}
		if (done == 1)
			p = p - got + i;        /* the '\n' itself */
	}
	term_row(row, out, width, 0);
	/* Start of the next line: past the newline, or end of buffer. */
	return p < n ? p + 1 : n;
}

static void
refresh(void)
{
	char title[MAXCOLS + 1];
	off_t p;
	off_t cur;
	off_t q;
	int body;
	int row;
	int crow;
	int ccol;
	int cfound;

	term_size(&E.rows, &E.cols);
	if (E.cols > MAXCOLS)
		E.cols = MAXCOLS;
	ensure_visible();
	term_put("\033[?25l");
	(void)strcpy(title, "  novi         ");
	(void)strncat(title, E.name[0] ? E.name : "New Buffer",
	    MAXCOLS - strlen(title));
	if (E.text.changed)
		(void)strncat(title, "  (modified)", MAXCOLS - strlen(title));
	(void)strncat(title, E.overwrite ? "  [OVR]" : "  [INS]",
	    MAXCOLS - strlen(title));
	put_padded(0, title, 1);
	body = body_rows();
	p = E.top;
	cur = buf_pos(&E.text);
	crow = 0;
	cfound = 0;
	for (row = 0; row < body; ++row) {
		q = draw_line(row + 1, p);
		if (!cfound && on_line(cur, p, q)) {
			crow = row;
			cfound = 1;
		}
		if (q != p)
			p = q;
	}
	put_padded(body + 1, E.message, 1);
	if (E.rows > 6) {
		put_padded(body + 2,
		    "^G Help  ^O Write Out  ^W Where Is  ^K Cut  ^U Uncut", 0);
		put_padded(body + 3,
		    "^X Exit  ^R Read  ^Y PgUp  ^V PgDn  ^A Home  ^E End  Ins Mode", 0);
	}
	ccol = visual_col(&E.text, cur) - E.hscroll;
	if (ccol < 0)
		ccol = 0;
	if (ccol >= E.cols)
		ccol = E.cols - 1;
	term_move(crow + 1, ccol);
	term_put("\033[?25h");
}

static int
prompt(char *label, char *answer, int size)
{
	int n;
	int key;
	char shown[MAXCOLS + 1];

	n = strlen(answer);
	for (;;) {
		(void)strncpy(shown, label, MAXCOLS);
		shown[MAXCOLS] = '\0';
		(void)strncat(shown, answer, MAXCOLS - strlen(shown));
		message(shown);
		refresh();
		key = term_key();
		if (key == '\r' || key == '\n')
			return 1;
		if (key == CTRL('C') || key == 27) {
			message("Cancelled");
			return 0;
		}
		if (key == 127 || key == CTRL('H')) {
			if (n > 0)
				answer[--n] = '\0';
		} else if (key >= 32 && key < 127 && n < size - 1) {
			answer[n++] = key;
			answer[n] = '\0';
		}
	}
}

static void
move_vertical(int down)
{
	off_t cur;
	off_t start;
	off_t target;

	cur = buf_pos(&E.text);
	start = line_start(&E.text, cur);
	if (E.wanted < 0)
		E.wanted = visual_col(&E.text, cur);
	if (down) {
		target = line_end(&E.text, start);
		if (target == buf_size(&E.text))
			return;
		++target;
	} else {
		if (start == 0)
			return;
		target = line_start(&E.text, start - 1);
	}
	(void)buf_seek(&E.text, at_column(&E.text, target, E.wanted));
}

static void
page_move(int down)
{
	off_t p;
	off_t q;
	int i;
	int count;

	count = body_rows() - 1;
	for (i = 0; i < count; ++i)
		move_vertical(down);
	p = E.top;
	for (i = 0; i < count; ++i) {
		if (down) {
			q = next_line(&E.text, p);
			if (q == p)
				break;
			p = q;
		} else {
			if (p == 0)
				break;
			p = line_start(&E.text, p - 1);
		}
	}
	E.top = p;
}

static void
type_character(int ch)
{
	off_t p;
	int replace;

	p = buf_pos(&E.text);
	replace = E.overwrite && p < buf_size(&E.text) &&
	    buf_get(&E.text, p) != '\n';
	if (buf_insert(&E.text, ch) == 0 && replace)
		(void)buf_delete(&E.text);
}

static void
do_write(void)
{
	char name[MAXNAME + 1];

	(void)strcpy(name, E.name);
	if (!prompt("File Name to Write: ", name, sizeof name))
		return;
	if (!name[0]) {
		message("No file name");
		return;
	}
	if (buf_save(&E.text, name) < 0) {
		message("Error writing file");
		return;
	}
	(void)strcpy(E.name, name);
	message("Wrote file");
}

static void
do_read(void)
{
	char name[MAXNAME + 1];
	char block[BUF_CACHE];
	int fd;
	int n;
	int i;

	name[0] = '\0';
	if (!prompt("File to Insert: ", name, sizeof name))
		return;
	fd = open(name, O_RDONLY, 0);
	if (fd < 0) {
		message("Cannot read file");
		return;
	}
	while ((n = read(fd, block, sizeof block)) > 0) {
		for (i = 0; i < n; ++i) {
			if (buf_insert(&E.text, (unsigned char)block[i]) < 0)
				break;
		}
		if (i != n)
			break;
	}
	(void)close(fd);
	message(n < 0 || (n > 0 && i != n) ? "Read error" : "Inserted file");
}

static void
do_search(void)
{
	char pat[80];
	off_t start;
	off_t p;
	off_t n;
	off_t q;
	int len;
	int i;
	int pass;

	pat[0] = '\0';
	if (!prompt("Search: ", pat, sizeof pat) || !pat[0])
		return;
	len = strlen(pat);
	n = buf_size(&E.text);
	start = buf_pos(&E.text);
	p = start < n ? start + 1 : 0;
	for (pass = 0; pass < 2; ++pass) {
		while (p + len <= n && (pass == 0 || p <= start)) {
			for (i = 0, q = p; i < len; ++i, ++q) {
				if (buf_get(&E.text, q) != (unsigned char)pat[i])
					break;
			}
			if (i == len) {
				(void)buf_seek(&E.text, p);
				message("Found");
				return;
			}
			++p;
		}
		p = 0;
	}
	message("Not found");
}

static void
do_position(void)
{
	off_t p;
	off_t n;
	off_t i;
	long line;
	int col;

	p = buf_pos(&E.text);
	n = buf_size(&E.text);
	line = 1;
	for (i = 0; i < p; ++i) {
		if (buf_get(&E.text, i) == '\n')
			++line;
	}
	col = visual_col(&E.text, p) + 1;
	(void)sprintf(E.message, "line %ld, column %d, character %ld of %ld",
	    line, col, (long)p, (long)n);
}

static void
do_cut(void)
{
	int ch;
	int any;
	unsigned char c;

	if (!E.cutappend) {
		(void)ftruncate(E.cutfd, (off_t)0);
		(void)lseek(E.cutfd, (off_t)0, L_SET);
	} else
		(void)lseek(E.cutfd, (off_t)0, L_XTND);
	any = 0;
	while ((ch = buf_delete(&E.text)) >= 0) {
		c = (unsigned char)ch;
		(void)write(E.cutfd, (char *)&c, 1);
		any = 1;
		if (ch == '\n')
			break;
	}
	E.cutappend = any;
	message(any ? "Cut text" : "Nothing to cut");
}

static void
do_uncut(void)
{
	char block[BUF_CACHE];
	int n;
	int i;

	(void)lseek(E.cutfd, (off_t)0, L_SET);
	while ((n = read(E.cutfd, block, sizeof block)) > 0) {
		for (i = 0; i < n; ++i)
			(void)buf_insert(&E.text, (unsigned char)block[i]);
	}
	message("Uncut text");
}

static void
help(void)
{
	int body;
	int row;
	char *lines[12];

	lines[0] = "novi help";
	lines[1] = "Arrows move; Home/End select line bounds; PgUp/PgDn page.";
	lines[2] = "^Y/^V page up/down ^P/^N up/down     ^B/^F left/right";
	lines[3] = "Ins toggles insert/overwrite mode    ^D/Del delete";
	lines[4] = "^A/^E home/end     ^R insert file   ^W search";
	lines[5] = "^O write file      ^K cut line      ^U uncut";
	lines[6] = "^C position        ^X exit";
	lines[7] = "Files are edited through disk scratch space, not held in RAM.";
	lines[8] = "Press any key to return.";
	lines[9] = "";
	lines[10] = "";
	lines[11] = "";
	body = E.rows < 12 ? E.rows : 12;
	term_clear();
	for (row = 0; row < body; ++row) {
		put_padded(row, lines[row], row == 0);
	}
	(void)term_key();
	message("");
}

static int
confirm_exit(void)
{
	int key;

	if (!E.text.changed)
		return 1;
	message("Save modified buffer?  Y Yes  N No  ^C Cancel");
	refresh();
	key = term_key();
	if (key == 'y' || key == 'Y') {
		do_write();
		return !E.text.changed;
	}
	if (key == 'n' || key == 'N')
		return 1;
	message("Cancelled");
	return 0;
}

static void
edit_loop(void)
{
	int key;

	for (;;) {
		refresh();
		key = term_key();
		if (key < 0)
			return;
		if (key != CTRL('K'))
			E.cutappend = 0;
		if (key == CTRL('X')) {
			if (confirm_exit())
				return;
		} else if (key == CTRL('G')) {
			help();
		} else if (key == CTRL('O')) {
			do_write();
		} else if (key == CTRL('R')) {
			do_read();
		} else if (key == CTRL('W')) {
			do_search();
		} else if (key == CTRL('C')) {
			do_position();
		} else if (key == CTRL('K')) {
			do_cut();
		} else if (key == CTRL('U')) {
			do_uncut();
		} else if (key == KEY_LEFT || key == CTRL('B')) {
			(void)buf_left(&E.text);
			E.wanted = -1;
		} else if (key == KEY_RIGHT || key == CTRL('F')) {
			(void)buf_right(&E.text);
			E.wanted = -1;
		} else if (key == KEY_UP || key == CTRL('P')) {
			move_vertical(0);
		} else if (key == KEY_DOWN || key == CTRL('N')) {
			move_vertical(1);
		} else if (key == KEY_HOME || key == CTRL('A')) {
			(void)buf_seek(&E.text, line_start(&E.text, buf_pos(&E.text)));
			E.wanted = -1;
		} else if (key == KEY_END || key == CTRL('E')) {
			(void)buf_seek(&E.text, line_end(&E.text, buf_pos(&E.text)));
			E.wanted = -1;
		} else if (key == KEY_PGUP || key == CTRL('Y')) {
			page_move(0);
		} else if (key == KEY_PGDN || key == CTRL('V')) {
			page_move(1);
		} else if (key == KEY_INSERT) {
			E.overwrite = !E.overwrite;
			message(E.overwrite ? "Overwrite mode" : "Insert mode");
		} else if (key == KEY_DELETE || key == CTRL('D')) {
			(void)buf_delete(&E.text);
			E.wanted = -1;
		} else if (key == 127 || key == CTRL('H')) {
			(void)buf_backspace(&E.text);
			E.wanted = -1;
		} else if (key == '\r' || key == '\n') {
			(void)buf_insert(&E.text, '\n');
			E.wanted = -1;
		} else if (key == '\t' || (key >= 32 && key < 256)) {
			type_character(key);
			E.wanted = -1;
		}
	}
}

static int
make_cutfile(void)
{
	char path[32];
	int fd;

	(void)strcpy(path, "/tmp/novicutXXXXXX");
	fd = mkstemp(path);
	if (fd >= 0)
		(void)unlink(path);
	return fd;
}

int
main(int argc, char **argv)
{
	char *name;

	name = argc > 1 ? argv[1] : "";
	(void)memset((char *)&E, 0, sizeof E);
	E.text.left = E.text.right = -1;
	E.cutfd = -1;
	E.wanted = -1;
	if (strlen(name) > MAXNAME) {
		(void)fprintf(stderr, "novi: file name too long\n");
		return 1;
	}
	(void)strcpy(E.name, name);
	if (buf_open(&E.text, name) < 0) {
		(void)fprintf(stderr, "novi: cannot open %s: %s\n", name,
		    strerror(errno));
		buf_close(&E.text);
		return 1;
	}
	E.cutfd = make_cutfile();
	if (E.cutfd < 0 || term_open() < 0) {
		(void)fprintf(stderr, "novi: cannot initialize terminal or scratch file\n");
		die(0);
		return 1;
	}
	(void)signal(SIGHUP, die);
	(void)signal(SIGTERM, die);
	(void)signal(SIGINT, die);
	message("Use ^G for help");
	edit_loop();
	die(0);
	return 0;
}

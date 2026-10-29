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
 * terminal.h -- raw mode, keys and cursor.  FGX delta: term_row and
 * term_dirty, the screen shadow's interface (terminal.c).
 */
#ifndef TERMINAL_H
#define TERMINAL_H

#define KEY_UP       256
#define KEY_DOWN     257
#define KEY_LEFT     258
#define KEY_RIGHT    259
#define KEY_HOME     260
#define KEY_END      261
#define KEY_PGUP     262
#define KEY_PGDN     263
#define KEY_DELETE   264
#define KEY_INSERT   265

int term_open(void);
void term_close(void);
void term_size(int *rows, int *cols);
int term_key(void);
void term_put(char *s);
void term_write(char *s, int n);
void term_move(int row, int col);
void term_clear(void);
void term_row(int row, char *cells, int n, int inverse);
void term_dirty(void);

#endif

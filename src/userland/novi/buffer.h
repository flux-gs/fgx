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
 * buffer.h -- the disk-backed gap buffer.  The document is never in memory:
 * text before the cursor lives in one scratch file, text after it lives
 * REVERSED in a second, and the cursor is the gap between them.
 *
 * FGX delta: buf_read, the bulk read the redraw uses (buffer.c).
 */
#ifndef BUFFER_H
#define BUFFER_H

#include <sys/types.h>

#define BUF_CACHE 256

struct buffer {
	int left;
	int right;
	off_t nleft;
	off_t nright;
	int changed;
	int cachefd;
	off_t cachebase;
	int cachelen;
	unsigned char cache[BUF_CACHE];
};

int buf_open(struct buffer *b, char *name);
void buf_close(struct buffer *b);
off_t buf_size(struct buffer *b);
off_t buf_pos(struct buffer *b);
int buf_get(struct buffer *b, off_t pos);
int buf_read(struct buffer *b, off_t pos, char *dst, int n);
int buf_insert(struct buffer *b, int ch);
int buf_backspace(struct buffer *b);
int buf_delete(struct buffer *b);
int buf_left(struct buffer *b);
int buf_right(struct buffer *b);
int buf_seek(struct buffer *b, off_t pos);
int buf_save(struct buffer *b, char *name);

#endif

/* SPDX-License-Identifier: LicenseRef-Elvis
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: NetBSD-0.9 elvis recycle.c
 *   Ported from elvis 1.7 recycle.c as vendored in NetBSD 0.9
 *   (vendor/netbsd-0-9/usr.bin/elvis/recycle.c), by Steve Kirkendall.
 *   Elvis's terms (its README): "Elvis is freely redistributable, in either
 *   source form or executable form.  There are no restrictions on how you may
 *   use it."  FGX's changes are BSD-2-Clause.
 *
 * VERBATIM EXCEPT FOR ONE WORD: garbage()'s `oldhdr` is `static` here instead of
 * automatic.  A diff against the vendored file should show exactly that hunk.
 *
 * WHY.  BLKSIZE is 2048, so that one local is a 2 KB stack frame.  It is not
 * merely large, it is on the chain that SETS vi's stack size.  stack_measure's
 * one-hop allowance uses `maxfn`, the deepest SUBTREE rooted at a non-entry
 * function, and charges it TWICE (fn-ptr dispatch + signal handler).  Measured
 * chain, before this change:
 *
 *     v_overtype  frame     4   subtree  4664   <- maxfn
 *       v_subst   frame     0   subtree  4647
 *       input     frame    18   subtree  4630
 *       v_popup   frame    10   subtree  4599
 *       v_undo    frame     0   subtree  4580
 *       undo      frame  2048   subtree  4575   <- here
 *       beforedo  frame     6   subtree  2520
 *       garbage   frame  2050   subtree  2509   <- and here
 *
 * undo + garbage are 4,098 of that 4,664, so they set the allowance and every
 * byte removed is worth two.  vi could not be started beside tcsh at all --
 * "stk ENOMEM 52p / Cannot allocate memory".
 *
 * WHY THIS IS SAFE.  garbage() is not recursive: it does not appear in the SCC the
 * measurer reports for this binary, i.e. the call graph shows no path from it
 * back to itself.  FGX signal handlers are flag-setters that return
 * (docs/userland-abi.md 6A), so there is no asynchronous re-entry either.  With
 * no recursion a static's lifetime is indistinguishable from the automatic it
 * replaces.  Same reasoning, and same idiom, as src/userland/elvis/modify.c --
 * and elvis itself already keeps BLK scratch at file scope (`hdr`, `tmpblk`).
 */
/* recycle.c */

/* Author:
 *	Steve Kirkendall
 *	14407 SW Teal Blvd. #C
 *	Beaverton, OR 97005
 *	kirkenda@cs.pdx.edu
 */


/* This file contains the functions perform garbage collection and allocate
 * reusable blocks.
 */

#include "config.h"
#include "vi.h"

#ifndef NO_RECYCLE
/* this whole file would have be skipped if NO_RECYCLE is defined */


#define BTST(bitno, byte)	((byte) & (1 << (bitno)))
#define BSET(bitno, byte)	((byte) |= (1 << (bitno)))
#define BCLR(bitno, byte)	((byte) &= ~(1 << (bitno)))

#define TST(blkno)		((blkno) < MAXBIT ? BTST((blkno) & 7, bitmap[(blkno) >> 3]) : 1)
#define SET(blkno)		if ((blkno) < MAXBIT) BSET((blkno) & 7, bitmap[(blkno) >> 3])
#define CLR(blkno)		if ((blkno) < MAXBIT) BCLR((blkno) & 7, bitmap[(blkno) >> 3])

/* bitmap of free blocks in first 4096k of tmp file */
static unsigned char bitmap[512];
#define MAXBIT	(sizeof bitmap << 3)

/* this function locates all free blocks in the current tmp file */
void garbage()
{
	int	i;
	static BLK	oldhdr;	/* FGX: static -- see header */

	/* start by assuming every block is free */
	for (i = 0; i < sizeof bitmap; i++)
	{
		bitmap[i] = 255;
	}

	/* header blocks aren't free */
#ifndef lint
	CLR(0);
	CLR(1);
#endif

	/* blocks needed for current hdr aren't free */
	for (i = 1; i < MAXBLKS; i++)
	{
		CLR(hdr.n[i]);
	}

	/* blocks needed for undo version aren't free */
	lseek(tmpfd, 0L, 0);
	if (read(tmpfd, &oldhdr, (unsigned)sizeof oldhdr) != sizeof oldhdr)
	{
		msg("garbage() failed to read oldhdr??");
		for (i = 0; i < sizeof bitmap; i++)
		{
			bitmap[i] = 0;
		}
		return;
	}
	for (i = 1; i < MAXBLKS; i++)
	{
		CLR(oldhdr.n[i]);
	}

	/* blocks needed for cut buffers aren't free */
	for (i = cutneeds(&oldhdr) - 1; i >= 0; i--)
	{
		CLR(oldhdr.n[i]);
	}
}

/* This function allocates the first available block in the tmp file */
long allocate()
{
	int	i;
	long	offset;

	/* search for the first byte with a free bit set */
	for (i = 0; i < sizeof bitmap && bitmap[i] == 0; i++)
	{
	}

	/* if we hit the end of the bitmap, return the end of the file */
	if (i == sizeof bitmap)
	{
		offset = lseek(tmpfd, 0L, 2);
	}
	else /* compute the offset for the free block */
	{
		for (i <<= 3; TST(i) == 0; i++)
		{
		}
		offset = (long)i * (long)BLKSIZE;

		/* mark the block as "allocated" */
		CLR(i);
	}

	return offset;
}

#endif

#ifdef DEBUG
# include <stdio.h>
# undef malloc
# undef free
# define MEMMAGIC 0x19f72cc0L
# define MAXALLOC 800
static char *allocated[MAXALLOC];
static char *fromfile[MAXALLOC];
static int  fromline[MAXALLOC]; 
static int  sizes[MAXALLOC];

char *dbmalloc(size, file, line)
	int	size;
	char	*file;
	int	line;
{
	char	*ret;
	int	i;

	size = size + sizeof(long) - (size % sizeof(long));
	ret = (char *)malloc(size + 2 * sizeof(long)) + sizeof(long);
	for (i = 0; i < MAXALLOC && allocated[i]; i++)
	{
	}
	if (i == MAXALLOC)
	{
		endwin();
		fprintf(stderr, "\r\n%s(%d): Too many malloc calls!\n", file, line);
		abort();
	}
	sizes[i] = size/sizeof(long);
	allocated[i] = ret;
	fromfile[i] = file;
	fromline[i] = line;
	((long *)ret)[-1] = MEMMAGIC;
	((long *)ret)[sizes[i]] = MEMMAGIC;
	return ret;
}

dbfree(ptr, file, line)
	char	*ptr;
	char	*file;
	int	line;
{
	int	i;

	for (i = 0; i < MAXALLOC && allocated[i] != ptr; i++)
	{
	}
	if (i == MAXALLOC)
	{
		endwin();
		fprintf(stderr, "\r\n%s(%d): attempt to free mem that wasn't allocated\n", file, line);
		abort();
	}
	allocated[i] = (char *)0;
	if (((long *)ptr)[-1] != MEMMAGIC)
	{
		endwin();
		fprintf(stderr, "\r\n%s(%d): underflowed malloc space, allocated at %s(%d)\n", file, line, fromfile[i], fromline[i]);
		abort();
	}
	if (((long *)ptr)[sizes[i]] != MEMMAGIC)
	{
		endwin();
		fprintf(stderr, "\r\n%s(%d): overflowed malloc space, allocated at %s(%d)\n", file, line, fromfile[i], fromline[i]);
		abort();
	}
	free(ptr - sizeof(long));
}

dbcheckmem(file, line)
	char	*file;
	int	line;
{
	int	i, j;

	for (i = j = 0; i < MAXALLOC && allocated[i]; i++)
	{
		if (((long *)allocated[i])[-1] != MEMMAGIC)
		{
			if (!j) endwin();
			fprintf(stderr, "\r\n%s(%d): underflowed malloc space, allocated at %s(%d)\n", file, line, fromfile[i], fromline[i]);
			j++;
		}
		if (((long *)allocated[i])[sizes[i]] != MEMMAGIC)
		{
			if (!j) endwin();
			fprintf(stderr, "\r\n%s(%d): overflowed malloc space, allocated at %s(%d)\n", file, line, fromfile[i], fromline[i]);
			j++;
		}
	}
	if (j)
	{
		abort();
	}
}
#endif

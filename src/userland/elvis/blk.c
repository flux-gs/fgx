/* SPDX-License-Identifier: LicenseRef-Elvis
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: NetBSD-0.9 elvis blk.c
 *   Ported from elvis 1.7 blk.c as vendored in NetBSD 0.9
 *   (vendor/netbsd-0-9/usr.bin/elvis/blk.c), by Steve Kirkendall.
 *   Elvis's terms (its README): "Elvis is freely redistributable, in either
 *   source form or executable form.  There are no restrictions on how you may
 *   use it."  FGX's changes are BSD-2-Clause.
 *
 * VERBATIM EXCEPT FOR ONE WORD: undo()'s `oldhdr` is `static` here instead of
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
 * WHY THIS IS SAFE.  undo() is not recursive: it does not appear in the SCC the
 * measurer reports for this binary, i.e. the call graph shows no path from it
 * back to itself.  FGX signal handlers are flag-setters that return
 * (docs/userland-abi.md 6A), so there is no asynchronous re-entry either.  With
 * no recursion a static's lifetime is indistinguishable from the automatic it
 * replaces.  Same reasoning, and same idiom, as src/userland/elvis/modify.c --
 * and elvis itself already keeps BLK scratch at file scope (`hdr`, `tmpblk`).
 */
/* blk.c */

/* Author:
 *	Steve Kirkendall
 *	14407 SW Teal Blvd. #C
 *	Beaverton, OR 97005
 *	kirkenda@cs.pdx.edu
 */


/* This file contains the functions that get/put blocks from the temp file.
 * It also contains the "do" and "undo" functions.
 */

#include "config.h"
#include "vi.h"

#ifndef NBUFS
# define NBUFS	5		/* must be at least 3 -- more is better */
#endif


/*------------------------------------------------------------------------*/

BLK		hdr;		/* buffer for the header block */

static int	b4cnt;		/* used to count context of beforedo/afterdo */
static struct _blkbuf
{
	BLK		buf;		/* contents of a text block */
	unsigned short	logical;	/* logical block number */
	int		dirty;		/* must the buffer be rewritten? */
}
		blk[NBUFS],	/* buffers for text[?] blocks */
		*toonew,	/* buffer which shouldn't be recycled yet */
		*newtoo,	/* another buffer which should be recycled */
		*recycle = blk;	/* next block to be recycled */



void blkflush P_((REG struct _blkbuf *this));




/* This function wipes out all buffers */
void blkinit()
{
	int	i;

	for (i = 0; i < NBUFS; i++)
	{
		blk[i].logical = 0;
		blk[i].dirty = FALSE;
	}
	for (i = 0; i < MAXBLKS; i++)
	{
		hdr.n[i] = 0;
	}
}

/* This function allocates a buffer and fills it with a given block's text */
BLK *blkget(logical)
	int	logical;	/* logical block number to fetch */
{
	REG struct _blkbuf	*this;	/* used to step through blk[] */
	REG int	i;

	/* if logical is 0, just return the hdr buffer */
	if (logical == 0)
	{
		return &hdr;
	}

	/* see if we have that block in mem already */
	for (this = blk; this < &blk[NBUFS]; this++)
	{
		if (this->logical == (unsigned)logical)
		{
			newtoo = toonew;
			toonew = this;
			return &this->buf;
		}
	}

	/* choose a block to be recycled */
	do
	{
		this = recycle++;
		if (recycle == &blk[NBUFS])
		{
			recycle = blk;
		}
	} while (this == toonew || this == newtoo);

	/* if it contains a block, flush that block */
	blkflush(this);

	/* fill this buffer with the desired block */
	this->logical = logical;
	if (hdr.n[logical])
	{
		/* it has been used before - fill it from tmp file */
		lseek(tmpfd, (long)hdr.n[logical] * (long)BLKSIZE, 0);
		if (read(tmpfd, this->buf.c, (unsigned)BLKSIZE) != BLKSIZE)
		{
			msg("Error reading back from tmp file!");
		}
	}
	else
	{
		/* it is new - zero it */
		for (i = 0; i < BLKSIZE; i++)
		{
			this->buf.c[i] = 0;
		}
	}

	/* This isn't really a change, but it does potentially invalidate
	 * the kinds of shortcuts that the "changes" variable is supposed
	 * to protect us from... so count it as a change.
	 */
	changes++;

	/* mark it as being "not dirty" */
	this->dirty = 0;

	/* return it */
	newtoo = toonew;
	toonew = this;
	return &this->buf;
}



/* This function writes a block out to the temporary file */
void blkflush(this)
	REG struct _blkbuf	*this;	/* the buffer to flush */
{
	long		seekpos;	/* seek position of the new block */
	unsigned short	physical;	/* physical block number */

	/* if its empty (an orphan blkadd() maybe?) then make it dirty */
	if (this->logical && !*this->buf.c)
	{
		blkdirty(&this->buf);
	}

	/* if it's an empty buffer or a clean version is on disk, quit */
	if (!this->logical || hdr.n[this->logical] && !this->dirty)
	{
		return;
	}

	/* find a free place in the file */
#ifndef NO_RECYCLE
	seekpos = allocate();
	lseek(tmpfd, seekpos, 0);
#else
	seekpos = lseek(tmpfd, 0L, 2);
#endif
	physical = seekpos / BLKSIZE;

	/* put the block there */
	if (write(tmpfd, this->buf.c, (unsigned)BLKSIZE) != BLKSIZE)
	{
		msg("Trouble writing to tmp file");
		deathtrap(0);
	}
	this->dirty = FALSE;

	/* update the header so it knows we put it there */
	hdr.n[this->logical] = physical;
}


/* This function sets a block's "dirty" flag or deletes empty blocks */
void blkdirty(bp)
	BLK	*bp;	/* buffer returned by blkget() */
{
	REG int		i, j;
	REG char	*scan;
	REG int		k;

	/* find the buffer */
	for (i = 0; i < NBUFS && bp != &blk[i].buf; i++)
	{
	}
#ifdef DEBUG
	if (i >= NBUFS)
	{
		msg("blkdirty() called with unknown buffer at 0x%lx", bp);
		return;
	}
	if (blk[i].logical == 0)
	{
		msg("blkdirty called with freed buffer");
		return;
	}
#endif

	/* if this block ends with line# INFINITY, then it must have been
	 * allocated unnecessarily during tmpstart().  Forget it.
	 */
	if (lnum[blk[i].logical] == INFINITY)
	{
#ifdef DEBUG
		if (blk[i].buf.c[0])
		{
			msg("bkldirty called with non-empty extra BLK");
		}
#endif
		blk[i].logical = 0;
		blk[i].dirty = FALSE;
		return;
	}

	/* count lines in this block */
	for (j = 0, scan = bp->c; *scan && scan < bp->c + BLKSIZE; scan++)
	{
		if (*scan == '\n')
		{
			j++;
		}
	}

	/* adjust lnum, if necessary */
	k = blk[i].logical;
	j += (lnum[k - 1] - lnum[k]);
	if (j != 0)
	{
		nlines += j;
		while (k < MAXBLKS && lnum[k] != INFINITY)
		{
			lnum[k++] += j;
		}
	}

	/* if it still has text, mark it as dirty */
	if (*bp->c)
	{
		blk[i].dirty = TRUE;
	}
	else /* empty block, so delete it */
	{
		/* adjust the cache */
		k = blk[i].logical;
		for (j = 0; j < NBUFS; j++)
		{
			if (blk[j].logical >= (unsigned)k)
			{
				blk[j].logical--;
			}
		}

		/* delete it from hdr.n[] and lnum[] */
		blk[i].logical = 0;
		blk[i].dirty = FALSE;
		while (k < MAXBLKS - 1)
		{
			hdr.n[k] = hdr.n[k + 1];
			lnum[k] = lnum[k + 1];
			k++;
		}
		hdr.n[MAXBLKS - 1] = 0;
		lnum[MAXBLKS - 1] = INFINITY;
	}
}


/* insert a new block into hdr, and adjust the cache */
BLK *blkadd(logical)
	int	logical;	/* where to insert the new block */
{
	static long	chg;
	REG int	i;

	/* if we're approaching the limit, then give a warning */
	if (hdr.n[MAXBLKS - 10] && chg != changes)
	{
		chg = changes;
		msg("WARNING: The edit buffer will overflow soon.");
	}
	if (hdr.n[MAXBLKS - 2])
	{
		msg("BAD NEWS: edit buffer overflow -- GOOD NEWS: text preserved");
		deathtrap(0);
	}

	/* adjust hdr and lnum[] */
	for (i = MAXBLKS - 1; i > logical; i--)
	{
		hdr.n[i] = hdr.n[i - 1];
		lnum[i] = lnum[i - 1];
	}
	hdr.n[logical] = 0;
	lnum[logical] = lnum[logical - 1];

	/* adjust the cache */
	for (i = 0; i < NBUFS; i++)
	{
		if (blk[i].logical >= (unsigned)logical)
		{
			blk[i].logical++;
		}
	}

	/* return the new block, via blkget() */
	return blkget(logical);
}


/* This function forces all dirty blocks out to disk */
void blksync()
{
	int	i;

	for (i = 0; i < NBUFS; i++)
	{
		/* blk[i].dirty = TRUE; */
		blkflush(&blk[i]);
	}
	if (*o_sync)
	{
		sync();
	}
}

/*------------------------------------------------------------------------*/

static MARK	undocurs;	/* where the cursor should go if undone */
static long	oldnlines;
static long	oldlnum[MAXBLKS];


/* This function should be called before each command that changes the text.
 * It defines the state that undo() will reset the file to.
 */
void beforedo(forundo)
	int		forundo;	/* boolean: is this for an undo? */
{
	REG int		i;
	REG long	l;

	/* if this is a nested call to beforedo, quit! Use larger context */
	if (b4cnt++ > 0)
	{
		return;
	}

	/* force all block buffers to disk */
	blksync();

#ifndef NO_RECYCLE
	/* perform garbage collection on blocks from tmp file */
	garbage();
#endif

	/* force the header out to disk */
	lseek(tmpfd, 0L, 0);
	if (write(tmpfd, hdr.c, (unsigned)BLKSIZE) != BLKSIZE)
	{
		msg("Trouble writing header to tmp file");
		deathtrap(0);
	}

	/* copy or swap oldnlines <--> nlines, oldlnum <--> lnum */
	if (forundo)
	{
		for (i = 0; i < MAXBLKS; i++)
		{
			l = lnum[i];
			lnum[i] = oldlnum[i];
			oldlnum[i] = l;
		}
		l = nlines;
		nlines = oldnlines;
		oldnlines = l;
	}
	else
	{
		for (i = 0; i < MAXBLKS; i++)
		{
			oldlnum[i] = lnum[i];
		}
		oldnlines = nlines;
	}

	/* save the cursor position */
	undocurs = cursor;

	/* upon return, the calling function continues and makes changes... */
}

/* This function marks the end of a (nested?) change to the file */
void afterdo()
{
	if (--b4cnt)
	{
		/* after abortdo(), b4cnt may decribe nested beforedo/afterdo
		 * pairs incorrectly.  If it is decremented to often, then
		 * keep b4cnt sane but don't do anything else.
		 */
		if (b4cnt < 0)
			b4cnt = 0;

		return;
	}

	/* make sure the cursor wasn't left stranded in deleted text */
	if (markline(cursor) > nlines)
	{
		cursor = MARK_LAST;
	}
	/* NOTE: it is still possible that markidx(cursor) is after the
	 * end of a line, so the Vi mode will have to take care of that
	 * itself */

	/* if a significant change has been made to this file, then set the
	 * MODIFIED flag.
	 */
	if (significant)
	{
		setflag(file, MODIFIED);
		setflag(file, UNDOABLE);
	}	
}

/* This function cuts short the current set of changes.  It is called after
 * a SIGINT.
 */
void abortdo()
{
	/* finish the operation immediately. */
	if (b4cnt > 0)
	{
		b4cnt = 1;
		afterdo();
	}

	/* in visual mode, the screen is probably screwed up */
	if (mode == MODE_COLON)
	{
		mode = MODE_VI;
	}
	if (mode == MODE_VI)
	{
		redraw(MARK_UNSET, FALSE);
	}
}

/* This function discards all changes made since the last call to beforedo() */
int undo()
{
	static BLK	oldhdr;	/* FGX: static, not automatic -- see header */

	/* if beforedo() has never been run, fail */
	if (!tstflag(file, UNDOABLE))
	{
		msg("You haven't modified this file yet.");
		return FALSE;
	}

	/* read the old header form the tmp file */
	lseek(tmpfd, 0L, 0);
	if (read(tmpfd, oldhdr.c, (unsigned)BLKSIZE) != BLKSIZE)
	{
		msg("Trouble rereading the old header from tmp file");
	}

	/* "do" the changed version, so we can undo the "undo" */
	cursor = undocurs;
	beforedo(TRUE);
	afterdo();

	/* wipe out the block buffers - we can't assume they're correct */
	blkinit();

	/* use the old header -- and therefore the old text blocks */
	hdr = oldhdr;

	/* This is a change */
	significant = TRUE;
	changes++;

	return TRUE;
}

/*==============================================================================
 * addtest.c -- Task 8 acceptance harness for the fcc per-task software stack.
 *
 * The payoff test for the whole soft-stack initiative.  It runs the REAL elvis
 * modify.c add() -- the "modify:190" case, whose two automatic BLK buffers
 * (`buf`, `linebuf`, 2 KB each at BLKSIZE=2048 => a ~4 KB frame) overflowed the
 * old hardware-frame model's 2048-slot cap.  With the soft-stack (per-task
 * malloc'd frame region, MAX_SOFT_SLOTS=6144) add() both COMPILES (Task 5) AND
 * RUNS.  Here we drive add() against an IN-MEMORY block cache (no tmp file /
 * machine layer needed -- add() only touches blkget/blkadd/blkdirty) and verify
 * that an insert edit produces the correct buffer contents.  Exit 42 = pass.
 *
 * Built FGX2 with the elvis config flags (see
 * docs/history/resume/RESUME-2026-07-01-elvis-fcc-gap-campaign.md):
 *   -DBSD=1 -DTINYSTACK=1 -DNEWSTYLE=0 -I<vendor/netbsd-0-9/usr.bin/elvis>
 *============================================================================*/

#include <stdio.h>

/* Pull in the REAL elvis add()/delete()/change() plus the vi.h cascade
 * (config.h, vi.h, ... all resolved via -I<elvis>). */
#include "modify.c"

/*----------------------------------------------------------------------------*/
/* In-memory block cache + the globals modify.c leaves `extern` in vi.h.  In    */
/* real elvis these live in blk.c/tmp.c backed by a temp file; the harness      */
/* models the logical-block array directly in RAM so add() runs standalone.     */
/*----------------------------------------------------------------------------*/
#define NPOOL 8

BLK   blkpool[NPOOL];    /* logical block i lives at blkpool[i] */
BLK   hdr;              /* header block: unused by add(), but vi.h extern's it */
long  lnum[MAXBLKS];    /* last line# of each block */
long  nlines;           /* number of lines in the "file" */
MARK  mark[NMARKS];     /* named marks 'a..'z and '' */
MARK  cursor;           /* current cursor mark (referenced by delete/change) */
long  changes;          /* bumped by each edit (vi.h: long) */
int   significant;
long  rptlines;
char *rptlabel;
int   bavar;            /* BeforeAfter() macro loop var (change() dead path) */
char  dbg[48];          /* global (seg1) scratch for a write()-based dump */

/* blkget: in RAM the logical block simply IS blkpool[logical]. */
BLK *blkget(logical)
	int logical;
{
	return &blkpool[logical];
}

/* blkadd: insert an empty logical block at `logical`, shifting the pool and
 * lnum[] up by one (byte-loop copy -- no struct assignment on the hot path).
 * Not exercised by the single-block test below, but present so the whole of
 * modify.c (add/delete/change) links and any block-split path is well-defined. */
BLK *blkadd(logical)
	int logical;
{
	int i, j;

	for (i = NPOOL - 1; i > logical; i--)
	{
		for (j = 0; j < BLKSIZE; j++)
		{
			blkpool[i].c[j] = blkpool[i - 1].c[j];
		}
	}
	for (j = 0; j < BLKSIZE; j++)
	{
		blkpool[logical].c[j] = 0;
	}
	for (i = MAXBLKS - 1; i > logical; i--)
	{
		lnum[i] = lnum[i - 1];
	}
	lnum[logical] = lnum[logical - 1];
	return &blkpool[logical];
}

void blkdirty(bp)
	BLK *bp;
{
	/* in-memory: the writes already landed in blkpool[]; nothing to flush */
}

void redrawrange(a, b, c)
	long a, b, c;
{
	/* the harness has no display */
}

/* Undo hooks reached only from change()'s ChangeText macro -- dead code here
 * (the harness calls add() directly), so empty stubs just satisfy the link. */
void beforedo(forundo)
	int forundo;
{
}

void afterdo()
{
}

/*----------------------------------------------------------------------------*/
/* The test                                                                     */
/*----------------------------------------------------------------------------*/

/* Seed one text block "<text>" as logical block 1, one line long. */
static void seed_block(text)
	char *text;
{
	int i;

	for (i = 0; text[i]; i++)
	{
		blkpool[1].c[i] = text[i];
	}
	blkpool[1].c[i] = 0;
	lnum[0] = 0;                 /* header block: 0 text lines */
	lnum[1] = 1;                /* block 1 ends at line 1 */
	for (i = 2; i < MAXBLKS; i++)
	{
		lnum[i] = INFINITY;
	}
	nlines = 1;
	for (i = 0; i < NMARKS; i++)
	{
		mark[i] = MARK_UNSET;
	}
}

/* Print "<msg>\n" via write() of a seg1 global buffer.  (printf's %-format
 * path is unreliable in this minimal harness; write() of a seg1 pointer is
 * solid, and the exit code -- readable via `echo $?` -- is the real verdict.) */
static void say(msg)
	char *msg;
{
	int n;

	n = 0;
	while (msg[n])
	{
		dbg[n] = msg[n];
		n++;
	}
	dbg[n++] = '\n';
	write(1, dbg, n);
}

/* True iff block 1 holds exactly the NUL-terminated string `expect`. */
static int block1_is(expect)
	char *expect;
{
	int i;

	for (i = 0; expect[i]; i++)
	{
		if (blkpool[1].c[i] != expect[i])
		{
			return 0;
		}
	}
	return blkpool[1].c[i] == 0;
}

int main()
{
	int ok;

	/* One text block: "hello world\n" as logical block 1. */
	seed_block("hello world\n");

	/* Insert "XYZ" at line 1, column 5 (between "hello" and " world"). */
	add(MARK_AT_LINE(1) + 5, "XYZ");

	/* add() snapshots the block (buf = *blk, a 2 KB soft-stack struct copy),
	 * rebuilds it with the inserted text, and copies the snapshot tail back
	 * via `newptr = buf.c` / `build = blk->c + (newptr - buf.c)` -- a true
	 * insert.  Correct result: "helloXYZ world\n". */
	ok = (changes != 0) && block1_is("helloXYZ world\n");

	say(ok ? "addtest: PASS" : "addtest: FAIL");
	return ok ? 42 : 1;
}

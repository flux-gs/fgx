/* softjmp - does a fork child that climbs BACK OVER the parent's soft frames
 * still leave them intact?
 *
 * FGX-Provenance: none
 *
 * softfork already forks from the bottom of a soft-frame recursion and has the
 * child recurse further.  Its own description records why that does not test
 * what it looks like it tests: the child inherits _fcc_sfp at the fork point
 * and its frames grow DOWNWARD into unused space, so disabling snapshot-fork's
 * pair-1 copy does not make it fail.  It names what a real control needs -- "a
 * child that moves sfp back UP over the parent's frames -- a longjmp to an
 * outer setjmp, which is what bsh does on error" -- and this is that.
 *
 * setjmp saves _fcc_sfp (setjmp.h, jmp_buf +10..11), so a longjmp from the
 * bottom of the recursion to a setjmp in main puts the CHILD's soft-frame
 * pointer back above every one of the parent's live frames.  The child then
 * recurses deeper than the parent did, so its frames cover the parent's
 * entirely, and writes a pattern the parent's values cannot produce.
 *
 * The parent is suspended in fork() at the bottom of the recursion the whole
 * time.  When the child _exits, the snapshot's pair 1 hands the soft bank
 * back; the parent unwinds and checks every frame it owns.  Any pair-1 copy
 * that misses part of the parent's live extent shows up here as SJBAD.
 *
 * Portable C: clang returns 41.
 */
#include <stdio.h>
#include <setjmp.h>
#include <unistd.h>
#include <sys/wait.h>

#define PARENT_DEPTH    8       /* frames the parent holds across the fork */
#define CHILD_DEPTH     14      /* deeper, so the child covers all of them */
#define SCRIBBLE        0x5A5A

jmp_buf	top;
int	forked;

/* Frames wide enough that the child's cover the parent's rather than
 * interleaving with them. */
int
scribble(n)
int n;
{
	int	pad[12];
	int	i;

	for (i = 0; i < 12; i++)
		pad[i] = SCRIBBLE;
	if (n > 0 && scribble(n - 1) < 0)
		return -1;
	return pad[0] == SCRIBBLE ? 0 : -1;
}

int
chain(n)
int n;
{
	int	mine;
	int	pid;
	int	st;

	mine = n * 7 + 3;		/* unique to THIS activation */
	if (n > 0) {
		if (chain(n - 1) < 0)
			return -1;
	} else if (!forked) {
		forked = 1;
		pid = fork();
		if (pid == 0)
			longjmp(top, 1);	/* climb out over the parent */
		if (pid < 0)
			return -1;
		wait(&st);
	}
	if (mine != n * 7 + 3)		/* the frame the child ran over */
		return -1;
	return mine;
}

int
main()
{
	if (setjmp(top) != 0) {
		/* THE CHILD, now at main's soft-frame level -- above every
		 * frame the parent still holds. */
		scribble(CHILD_DEPTH);
		_exit(0);
	}
	printf("SJSTART\n");
	if (chain(PARENT_DEPTH) != PARENT_DEPTH * 7 + 3) {
		printf("SJBAD\n");
		return 1;
	}
	printf("SJOK\n");
	return 41;
}

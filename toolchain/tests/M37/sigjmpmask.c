/* sigjmpmask: setjmp/longjmp SAVE AND RESTORE THE SIGNAL MASK (apple/fgx#64).
 * FGX-only (MAME oracle): needs real signal delivery.
 *
 * From 2.11BSD's own setjmp.3: "Setjmp and longjmp save and restore the signal
 * mask sigmask(2), while _setjmp and _longjmp manipulate only the C stack and
 * registers."  FGX's jmp_buf had no mask slot, so it behaved as _setjmp does.
 *
 * That only became a defect when #53 made a delivered signal BLOCKED for the
 * duration of its handler, as 2.11BSD's postsig() does -- crt0's trampoline
 * unblocks it again on NORMAL return, and a handler that longjmps out never
 * reaches that.  So the signal stayed blocked FOREVER.  Every vendored program
 * that longjmps out of a handler is affected; bsh was the first noticed
 * (fault.c does `longjmp(INTbuf, 1)`), and it took exactly one ^C.
 *
 * THE LOOP IS THE TEST.  Each round raises SIGINT at itself; the handler
 * counts and longjmps back here, so a round can only happen if the PREVIOUS
 * round's signal got unblocked.  One round passes on the broken libc -- hence
 * three.  Without the fix `hits` stops at 1: the second kill(2) posts SIGINT,
 * the mask left over from round 1 holds it pending, the syscall returns
 * normally and control falls straight out of the loop.
 *
 * The second check reads the mask through libc's own shadow rather than
 * inferring it from delivery, so a fix that repaired the kernel mask but left
 * the shadow stale (or the reverse) scores 21, not 42 -- libc computes
 * sigblock(m) as sigsetmask(shadow | m), so a stale shadow reinstates the
 * block at the next sigblock() call.
 *
 * 21 + 21 = 42. */
#include <signal.h>
#include <setjmp.h>

jmp_buf sjm_env;
int     sjm_hits;

void
sjm_onint(sig)
int sig;
{
	sjm_hits++;
	longjmp(sjm_env, 1);            /* the idiom that leaves it blocked */
}

int
main()
{
	int r;

	signal(SIGINT, sjm_onint);

	setjmp(sjm_env);                /* 0 first, then 1 per longjmp */
	if (sjm_hits < 3)
		kill(getpid(), SIGINT);

	/* Falls through here EITHER because three signals were delivered, or
	 * because a kill(2) came back without delivering one. */
	r = (sjm_hits == 3) ? 21 : 0;

	/* ...and the mask libc will hand the kernel at the next sigblock(). */
	if ((sigblock(0L) & sigmask(SIGINT)) == 0)
		r += 21;

	return r;                       /* 42 */
}

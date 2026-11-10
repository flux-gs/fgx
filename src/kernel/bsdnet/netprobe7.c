/* netprobe7 -- S3's cases: what a process needs from the stack.  setjmp and
 * longjmp in the kernel, and the stack's errno agreeing with userland's. */
#include "param.h"
#include "user.h"
#include "errno.h"

/* 52: one would-block errno, userland's (include/errno.s, toolchain errno.h). */
#if EWOULDBLOCK != EAGAIN
#include "netprobe7: EWOULDBLOCK must be EAGAIN"
#endif

static	label_t np7_env;
static	int np7_depth;

static void
np7_jump(n)
	int n;
{
	int mine;

	mine = np7_peek(&n);	/* a frame of its own in _fcc_fb */
	if (mine > 0) {
		np7_depth++;
		np7_jump(n - 1);
	}
	longjmp(&np7_env, 7);
}

static int
np7_peek(p)
	int *p;
{
	return (*p);
}

/* After the longjmp a local's address is taken afresh, which fcc builds from
 * _fcc_fb: np7_jump left its own frame there, so this reads the right local only
 * if longjmp put setjmp's back.  The pointer taken before the setjmp, and the
 * register local, are read back too. */
static int
np7_setjmp()
{
	register int kept;
	int seen, *where;

	kept = 0x5a5a;
	seen = 11;
	where = &seen;
	np7_depth = 0;
	if (setjmp(&np7_env)) {
		if (kept != 0x5a5a || *where != 11 || np7_peek(&seen) != 11 ||
		    np7_depth != 3)
			return (51);
		return (0);
	}
	seen = 11;
	np7_jump(3);
	return (51);		/* longjmp came back here */
}

int
netprobe7()
{
	return (np7_setjmp());
}

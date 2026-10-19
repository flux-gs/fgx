/* Fixture for fcc's use-before-set warning.  K&R 2nd ed 2.4, p.39:
 *
 *   "External and static variables are initialized to zero by default.
 *    Automatic variables for which is no explicit initializer have undefined
 *    (i.e., garbage) values."
 *
 * Every function here is named for the verdict it must draw, and
 * test_uninit_warn.py asserts BOTH directions -- the two that must warn and
 * the six that must not.  A warning that only ever fires is as useless as one
 * that never does.
 */

/* MUST WARN: read on every path, stored on none. */
int warn_never_set()
{
	int x;
	return x;
}

/* MUST WARN: the read precedes the only store, outside any loop. */
int warn_read_before_store()
{
	int y;
	int r;
	r = y;
	y = 3;
	return r;
}

/* QUIET: an explicit initializer is a store. */
int quiet_initialized()
{
	int a = 5;
	return a;
}

/* QUIET: stored before read. */
int quiet_stored_first()
{
	int b;
	b = 7;
	return b;
}

/* QUIET: the address escapes, so something else may fill it -- scanf, an
 * out-parameter, a memset.  This pass cannot see through that. */
int quiet_addr_taken()
{
	int c;
	fill(&c);
	return c;
}

/* QUIET: a parameter is set by the caller.  That is what a parameter is. */
int quiet_param(p)
	int p;
{
	return p;
}

/* QUIET, AND DELIBERATELY UNDER-REPORTED: `acc' really is read before it is
 * ever set, but the read is INSIDE a loop, and a loop body legitimately reads
 * on iteration two what iteration one stored.  Reporting loop reads would make
 * that ordinary shape noisy, so the loop arm is dropped rather than guessed
 * at.  This case is here to pin that choice, not to bless the code. */
int quiet_loop_carried()
{
	int i, acc;
	for (i = 0; i < 3; i++) {
		acc = acc + i;
	}
	return acc;
}

/* QUIET: a pointer stored through the FPR path.  This is the one that made the
 * first cut of the warning report 58 false positives across libc -- pointer
 * assignment breaks out of N_STORE_VAR before emit_store_local, so the store
 * was never counted. */
char *quiet_pointer_store(s)
	char *s;
{
	char *p;
	p = s;
	return p;
}

/* c39_fnptrret.c — POINTER return through a cross-bank fn-ptr call.
 *
 * P3-2 model edge: the returned (offset,bank) pair must survive the
 * 3-layer cross-bank fn-ptr dispatch (today: A + _fcc_ptr+2 across a
 * double-RTL; under the FPR model: FPR0 across the same dispatch).
 * The target (c39_target.c) is pinned in a DIFFERENT code bank and
 * returns a heap pointer it also stashes in a data-bank cell — the
 * caller cross-checks identity and derefs. */
extern char *c39_get();

char *(*c39_fp)();               /* fn-ptr global (data bank) */
char *c39_stash;                 /* filled by the target */

int
c39_check(void)
{
	char *r;
	c39_fp = c39_get;            /* &fn into a data-seg fn-ptr global */
	r = (*c39_fp)();
	if (!r) return 0;
	if (r != c39_stash) return 0;  /* same (offset,bank) both routes */
	return *r == 42;
}

/* M8: prefix ++/-- on a CHAINED arrow lvalue used as a VALUE --
 * `--pp->p_cwd->di_count == 0` (tcsh sh.proc).
 *
 * The per-shape handler took exactly ONE hop from the base to a
 * scalar/pointer leaf, so a member that is itself a struct POINTER (the chain
 * continuing) hit "prefix '++'/'--' on this '->' member type not supported".
 * K&R A.7.4.1 applies ++/-- to ANY modifiable lvalue, so depth is not a
 * language distinction; the uniform walker's chain mode handles it.
 *
 * Prefix yields the NEW value (K&R A.7.4.1: "the value is the new value of
 * the operand"), which the != comparisons below pin -- a postfix-style
 * old-value result would make every one of them wrong.  The memory checks
 * pin that the update actually landed in the pointee, not in a copy.
 *
 * Returns 42.
 */
struct inner {
	int  cnt;
	long big;
};

struct outer {
	struct inner *ip;
	int           n;
};

struct inner I;
struct outer O;
struct outer *pp;

int main()
{
	int r = 0;

	I.cnt = 5;
	I.big = 7L;
	O.ip  = &I;
	pp    = &O;

	if (--pp->ip->cnt == 4) r += 10;	/* value is the NEW one */
	if (I.cnt == 4)         r += 10;	/* and it reached memory */
	if (++pp->ip->cnt == 5) r += 11;
	if (I.cnt == 5)         r += 11;

	return r;			/* 10 + 10 + 11 + 11 = 42 */
}

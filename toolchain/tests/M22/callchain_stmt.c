/* A postfix chain on a CALL RESULT, in STATEMENT position (apple/fgx#153).
 * K&R A.7.1 makes '.'/'->'/'[]' one left-to-right postfix production over a
 * primary, and a call is a primary -- but the statement dispatcher's call arm
 * went straight to the ';' after the ')', so `lookup(n)->m = v;' died as
 * "expected ';'" while the identical expression inside parentheses parsed.
 * 2.11BSD sh compiles only because its attrib() is spelled `(n->namflg |= f)'.
 * Both spellings are here, and they must agree.  -> 42. */
struct namnod {
	struct namnod	*namlft;
	struct namnod	*namrgt;
	int		 namflg;
};
typedef struct namnod *NAMPTR;

struct namnod root;
int	vec[4];
int	calls;

NAMPTR
lookup(n)
	int n;
{
	calls++;
	return &root;
}

int *
ivec()
{
	calls++;
	return vec;
}

int main(void)
{
	root.namflg = 0;
	calls = 0;

	lookup(1)->namflg = 4;          /* statement, plain store   */
	if (root.namflg != 4)   return 1;

	lookup(1)->namflg |= 16;        /* statement, compound op   */
	if (root.namflg != 20)  return 2;

	(lookup(1)->namflg |= 8);       /* the parenthesized twin   */
	if (root.namflg != 28)  return 3;

	ivec()[2] = 5;                  /* index on a call result   */
	if (vec[2] != 5)        return 4;

	ivec()[2] += 3;
	if (vec[2] != 8)        return 5;

	/* ONE evaluation per statement, for BOTH kinds of base.  ivec() did not
	 * count when this fixture was written, so its two statements were
	 * outside the assertion -- and `ivec()[2] += 3' was in fact emitting the
	 * call TWICE (apple/fgx#155).  Five statements, five calls. */
	if (calls != 5)         return 6;

	return 42;
}

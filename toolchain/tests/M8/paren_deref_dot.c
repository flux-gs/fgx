/* paren_deref_dot: the PRIMITIVE spelling of a member selection.
 *
 * K&R A.7.3.3 p.164: "the expression E1->MOS is the same as (*E1).MOS".  fcc
 * accepted the derived form and rejected the primitive it is defined as, in
 * read, assign AND address-of context, with three different diagnostics
 * (apple/fgx#95).  A.7.3.1 p.162 supplies the second line's shape: E1[E2] is
 * "identical (by definition) to *((E1)+(E2))", so `(*(p+1)).f` is `p[1].f`
 * spelled out.
 *
 * Every line below is ordinary ANSI C, so the host compiler validates it
 * directly -- no pun, no dialect.  -> 15. */
struct s { int f; int g; };
struct s  a[2];
struct s *p;
int      *q;

int
main()
{
	p = &a[0];
	(*p).f     = 3;            /* store, primitive spelling           */
	(*(p + 1)).f = 4;          /* A.7.3.1: p[1].f, deref of a sum     */
	q = &(*p).g;               /* address-of, primitive spelling      */
	*q = 5;
	/* read in all three shapes, and the derived twin, which must agree */
	return (*p).f + (*(p + 1)).f + (*p).g + p->f;   /* 3 + 4 + 5 + 3 */
}

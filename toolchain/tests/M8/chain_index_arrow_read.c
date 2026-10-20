/* M8: value-leaving READ through a chain that RESUMES past a SUBSCRIPT --
 * `p->link[1]->bal` (tcsh sh.set's `p->v_right->v_bal`, where v_right is
 * itself a macro for v_link[1]).  K&R A.7.3 makes ./->/[] ONE recursive
 * postfix production with lvalue-ness propagating along it, so
 * arrow-then-index-then-arrow must read exactly like arrow-then-arrow; the
 * specialised arrow path consumes a single pointer hop and cannot cross an
 * index, which left this shape unparsable ("expected ')'").
 *
 * Also pins UNSIGNEDNESS across the walker: reads routed through
 * emit_lvalue_addr previously lost is_unsigned, so an `unsigned int` member
 * compared with '>' emitted the SIGNED helper and 50000 > 100 took the FALSE
 * branch.  Returns 42; 142 if unsignedness is dropped.
 *
 * Multi-hop (`p->link[1]->link[2]->bal`) keeps the far-pointer bank honest:
 * each hop must deref through the carrier, not a truncated 16-bit offset. */
struct node {
	struct node  *link[3];		/* ARRAY member  -> index step, no deref */
	struct node **many;		/* PTR-TO-PTR    -> index step WITH deref */
	int           bal;
	unsigned int  ubal;
};

struct node a, b, c, d;
struct node *ptrs[3];

int main()
{
	struct node *p, *q;
	int r = 0;

	/* Setup uses ARROW stores throughout: the dot-based twin `a.link[1] = &b`
	 * is a separately-known open gap (store through a subscripted pointer
	 * member of a DOT base), and tripping it here would mask what this
	 * fixture is for. */
	p = &a;
	q = &b;
	p->link[1] = &b;
	q->bal     = 10;
	q->ubal    = 50000;		/* > INT_MAX: signed compare reads negative */
	q->link[2] = &c;
	q = &c;
	q->bal     = 12;

	/* ptr-to-ptr leg: p->many[1] must DEREF the member, then scale by
	 * sizeof(struct node *) == 4 -- scaling by sizeof(struct node) instead
	 * lands on the wrong element and the total stops being 42. */
	ptrs[1] = &d;
	p->many = ptrs;
	q = &d;
	q->bal  = 20;
	q->ubal = 50000;

	r += p->link[1]->bal;			/* 10 : arrow -> index -> arrow   */
	if (p->link[1]->ubal > 100)		/* unsigned compare must be TRUE  */
		r += 0;
	else
		r += 100;			/* signed-compare bug lands here  */
	r += p->link[1]->link[2]->bal;		/* 12 : two index hops            */
	r += p->many[1]->bal;			/* 20 : deref'd index step -> 42  */
	if (p->many[1]->ubal > 100)
		r += 0;
	else
		r += 100;			/* unsigned lost on the ** leg    */

	return r;
}

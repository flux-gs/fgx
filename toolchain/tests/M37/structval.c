/* structval: a struct-typed member used as a VALUE, and a whole struct
 * assigned where an expression's value is wanted.
 *
 * K&R A.7.3.3 (p.163): "The value is the named member of the structure or
 * union, and its type is the type of the member."  For `->', "The result
 * refers to the named member of the structure or union to which the pointer
 * expression points".  A.7.3.2 (p.163): "In preparing for the call to a
 * function, a copy is made of each argument".  So `take(p->m)' passes the
 * member's six bytes and `(p->m).c' reads the member's own `c'.
 *
 * A struct value that is the member's FIRST WORD instead of its address
 * copies from, or reads through, whatever address that word spells: every
 * check below then sees garbage.  The sources are reached through a named
 * pointer, a pointer chain, an array element, a call, an element of a
 * struct-array member, and a conditional.
 *
 * 7 arms x 6 = 42. */

struct in { int a; int b; int c; };
struct sl { int before; struct in u; struct in sa[2]; int after; struct sl *nx; };

static struct sl g0, g1, g2;
static struct sl gvs[2];
static struct sl *gp;
static struct in sv;

struct sl *
mk()
{
	return &g2;
}

static int
take(s, a, b, c)
	struct in s;
	int a, b, c;
{
	return s.a == a && s.b == b && s.c == c;
}

static int
same(s, a, b, c)
	struct in *s;
	int a, b, c;
{
	return s->a == a && s->b == b && s->c == c;
}

static void
fill(s, v)
	struct in *s;
	int v;
{
	s->a = v; s->b = v + 1; s->c = v + 2;
}

int
main()
{
	int i = 1, k, x, r = 0;

	fill(&g0.u, 10); fill(&g0.sa[1], 13); g0.nx = &g1;
	fill(&g1.u, 20); fill(&g1.sa[1], 23);
	fill(&g2.u, 30); fill(&g2.sa[1], 33);
	fill(&gvs[1].u, 40); fill(&gvs[1].sa[1], 43);
	gp = &g0;

	/* A by-value argument through `->': a name, a chain, a call. */
	if (take(gp->u, 10, 11, 12) && take(gp->nx->u, 20, 21, 22) &&
	    take(mk()->u, 30, 31, 32))
		r += 6;

	/* A by-value argument that is an element of a struct-array member. */
	if (take(gp->sa[i], 13, 14, 15) && take(gp->nx->sa[1], 23, 24, 25) &&
	    take(mk()->sa[i], 33, 34, 35) && take(gvs[i].sa[1], 43, 44, 45))
		r += 6;

	/* `.' applied to a parenthesized struct member and to a conditional's
	 * struct value, and a member of an element of a struct-array member of
	 * an element. */
	x = (gp->u).c;
	if (x == 12 && (gvs[i].u).b == 41 && gvs[i].sa[1].b == 44 &&
	    (i ? gp->nx->u : gvs[i].u).a == 20)
		r += 6;

	/* A struct assignment after a comma: the comma's right operand. */
	k = 1, sv = gp->nx->u;
	if (k == 1 && same(&sv, 20, 21, 22)) r += 6;

	/* A struct assignment as a for-step. */
	for (k = 0; k < 2; sv = gvs[i].u)
		k++;
	if (k == 2 && same(&sv, 40, 41, 42)) r += 6;

	/* Call-led and conditional sources, and a store through a call's
	 * subscript. */
	sv = mk()->u;
	x = same(&sv, 30, 31, 32);
	sv = mk()->sa[1];
	k = same(&sv, 33, 34, 35);
	sv = !i ? gp->u : mk()->u;
	mk()[0].after = 7;
	if (x && k && same(&sv, 30, 31, 32) && g2.after == 7) r += 6;

	/* Every source is untouched, and so are the members either side. */
	if (same(&g0.u, 10, 11, 12) && same(&g1.sa[1], 23, 24, 25) &&
	    same(&gvs[1].u, 40, 41, 42) && g0.before == 0 && g0.after == 0)
		r += 6;

	return r;				/* 42 */
}

/* chain_structcopy: a whole struct assigned THROUGH a pointer chain or a
 * computed base.
 *
 * K&R A.7.17 (p.169): in simple assignment "the value of the expression
 * replaces that of the object referred to by the lvalue", and it admits
 * operands that "are structures or unions of the same type".  The OBJECT --
 * every byte, not its first word.
 *
 * `s.p->m = v;' reached a statement store that had no struct arm and wrote two
 * bytes of v's ADDRESS over the member.  `p->q->m = v;' reached a chain store
 * that stores a scalar.  Both compiled and both ran.  `f()->m = v' was refused
 * outright although the expression store it names copies structs already.
 *
 * THE STRUCT IS SIX BYTES AND EVERY WORD IS CHECKED, with the member either
 * side as a neighbour: a first-word store gets `a' wrong and leaves `b' and
 * `c'; a copy that runs long lands on `after'.
 *
 * 7 arms x 6 = 42. */

struct in { int a; int b; int c; };
struct sl { int before; struct in u; int after; struct sl *nx; };

static struct sl g0, g1, g2, g3;
static struct sl *gp;
static struct in iv;

struct sl *
mk()
{
	return &g2;
}

static int
same(s, a, b, c)
	struct in *s;
	int a, b, c;
{
	return s->a == a && s->b == b && s->c == c;
}

int
main()
{
	int k, r = 0;

	iv.a = 11; iv.b = 22; iv.c = 33;
	g0.nx = &g1; g1.nx = &g3;
	gp = &g0;
	g1.before = 5; g1.after = 6;
	g2.before = 7; g2.after = 8;
	g3.before = 9; g3.after = 10;

	/* A struct VARIABLE's pointer member, then the struct member. */
	g0.nx->u = iv;
	if (same(&g1.u, 11, 22, 33) && g1.before == 5 && g1.after == 6) r += 6;

	/* Two pointer hops from a pointer. */
	iv.a = 44;
	gp->nx->nx->u = iv;
	if (same(&g3.u, 44, 22, 33) && g3.before == 9 && g3.after == 10) r += 6;

	/* One hop from a pointer, then the member. */
	iv.b = 55;
	gp->nx->u = iv;
	if (same(&g1.u, 44, 55, 33) && g1.after == 6) r += 6;

	/* A COMPUTED base. */
	iv.c = 66;
	mk()->u = iv;
	if (same(&g2.u, 44, 55, 66) && g2.before == 7 && g2.after == 8) r += 6;

	/* The same in value position -- a comma operand. */
	iv.a = 77;
	k = 1, gp->nx->nx->u = iv;
	if (k == 1 && same(&g3.u, 77, 55, 66) && g3.after == 10) r += 6;

	/* A parenthesized base, the chain continuing after the parens. */
	iv.b = 88;
	k = 2, (gp)->nx->u = iv;
	if (k == 2 && same(&g1.u, 77, 88, 66)) r += 6;

	/* The source is untouched by all of it. */
	if (same(&iv, 77, 88, 66)) r += 6;

	return r;				/* 42 */
}

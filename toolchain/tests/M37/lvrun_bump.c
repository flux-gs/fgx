/* lvrun_bump: `++'/`--' on an lvalue reached through a RUN of `.', `->' and
 * `[', in value position and as a prefix statement.  apple/fgx#394, #395.
 *
 * K&R A.7.3.4 (p.164): "A postfix expression followed by a ++ or -- operator
 * is a postfix expression.  The value of the expression is the value of the
 * operand."  The operand is the whole run, however many suffixes built it --
 * and every spelling here was refused before, at a missing ';' or ')', because
 * each member reader bumps one fixed shape and otherwise returns a load.
 *
 * IT CHECKS THE YIELDED VALUE AS WELL AS THE STORE.  A postfix that yields the
 * new value, or a prefix that yields the old one, still compiles and still
 * bumps; only the value used shows it.  And every arm holds the NEIGHBOURING
 * element or member to its own value, because a run that folds its offsets
 * wrongly lands next door rather than failing.
 *
 * 14 arms x 3 = 42. */

struct in { int n; int m; };
struct sl {
	int        t;
	char       d[4];
	int        w[4];
	char      *cp;
	struct in  u;
	struct sl *nx;
};

static struct sl vs[3];
static struct sl obj;
static int m2[2][3];
static char buf[4];

int
main()
{
	struct sl *p;
	int i, x, r = 0;

	p = &obj;
	obj.t = 7;
	obj.w[0] = 10; obj.w[1] = 20; obj.w[2] = 30;

	/* A dot base, int element, VALUE position: the old value comes back. */
	x = obj.w[1]++;
	if (x == 20 && obj.w[1] == 21 && obj.w[0] == 10 && obj.w[2] == 30)
		r += 3;

	/* An arrow base, char element, runtime index, postfix `--'. */
	obj.d[0] = 'a'; obj.d[1] = 'b'; obj.d[2] = 'c';
	i = 1;
	x = p->d[i]--;
	if (x == 'b' && obj.d[1] == 'a' && obj.d[0] == 'a' && obj.d[2] == 'c')
		r += 3;

	/* An indexed base, scalar member, value position. */
	vs[0].t = 100; vs[1].t = 200; vs[2].t = 300;
	i = 1;
	x = vs[i].t++;
	if (x == 200 && vs[1].t == 201 && vs[0].t == 100 && vs[2].t == 300)
		r += 3;

	/* Arrow, then a dot into an embedded struct. */
	obj.u.n = 40; obj.u.m = 50;
	x = p->u.n++;
	if (x == 40 && obj.u.n == 41 && obj.u.m == 50 && obj.t == 7)
		r += 3;

	/* Indexed base, then an element of an array member, value position. */
	vs[2].w[1] = 60; vs[2].w[2] = 70; vs[1].w[1] = 80;
	i = 2;
	x = vs[i].w[1]--;
	if (x == 60 && vs[2].w[1] == 59 && vs[2].w[2] == 70 && vs[1].w[1] == 80)
		r += 3;

	/* The same, as a STATEMENT: routed rather than refused. */
	vs[0].w[3] = 5;
	vs[0].w[3]++;
	if (vs[0].w[3] == 6 && vs[0].w[2] == 0) r += 3;

	/* A PREFIX statement whose run continues past the member: `--s.a[i];'
	 * used to be desugared as `s.a -= 1' and die on the `['. */
	--obj.w[2];
	if (obj.w[2] == 29 && obj.w[1] == 21) r += 3;

	/* Prefix statement, arrow then dot. */
	++p->u.m;
	if (obj.u.m == 51 && obj.u.n == 41) r += 3;

	/* A POINTER member subscripted: the ELEMENT is bumped, not the pointer.
	 * `--p->cp[1]' used to bump `p->cp' and leave `[1]' unread. */
	buf[0] = 'x'; buf[1] = 'y'; buf[2] = 'z';
	obj.cp = buf;
	--p->cp[1];
	x = p->cp[2]++;
	if (buf[1] == 'x' && x == 'z' && buf[2] == 'z' + 1 && buf[0] == 'x' &&
	    obj.cp == buf)
		r += 3;

	/* The same pointer member through an indexed base, compound. */
	vs[1].cp = buf;
	vs[1].cp[0] += 2;
	if (buf[0] == 'x' + 2 && buf[1] == 'x') r += 3;

	/* `(*p).m' is `p->m' (K&R A.7.3.3), in value position as well. */
	x = ((*p).w[3] = 9) + 1;
	if (x == 10 && obj.w[3] == 9 && obj.w[2] == 29) r += 3;

	/* A TWO-DIMENSIONAL element: the first subscript steps a ROW (three
	 * ints), not an int.  Stepping by the element lands in row 0. */
	m2[0][2] = 1; m2[1][0] = 2; m2[1][2] = 3;
	x = m2[1][2]++;
	if (x == 3 && m2[1][2] == 4 && m2[0][2] == 1 && m2[1][0] == 2)
		r += 3;

	/* ...and stored in value position, with a runtime row. */
	i = 1;
	x = (m2[i][1] = 8) + 1;
	if (x == 9 && m2[1][1] == 8 && m2[0][1] == 0 && m2[1][2] == 4) r += 3;

	/* ...and as a statement, postfix. */
	m2[0][0]++;
	if (m2[0][0] == 1 && m2[0][1] == 0) r += 3;

	return r;				/* 42 */
}

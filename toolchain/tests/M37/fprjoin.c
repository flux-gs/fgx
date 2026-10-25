/* A pointer register at a label holds a pointer only when every path into
 * the label agrees.  pick: the arms of the ternary leave p and q in the same
 * register, so p->b after the join is a fresh load of p.  walk: p is in a
 * register when it reaches top, a user label reached again after p++
 * changes it, so p->a is loaded each time.
 * sel: an && in a condition is branches, and both of its exits reach the
 * same arm.  Returns 42 when every value is read through the right pointer. */
struct s { int a, b; };

struct s x[3] = { { 1, 2 }, { 10, 20 }, { 100, 200 } };

int
pick(c, p, q)
int c;
struct s *p, *q;
{
	return (c ? p->a : q->a) == 99 ? 0 : p->b;
}

int
walk(p, n)
struct s *p;
int n;
{
	int t;

	t = p->a - 1;
top:
	t += p->a;
	p++;
	if (--n)
		goto top;
	return t;
}

int
sel(p, q)
struct s *p, *q;
{
	if (p->a == 1 && q->a == 10)
		return p->b + q->b;
	return 0;
}

int
main()
{
	int r;

	r = 0;
	if (pick(1, &x[0], &x[1]) == 2) r += 10;
	if (pick(0, &x[0], &x[1]) == 2) r += 10;	/* p->b, not q->b */
	if (walk(&x[0], 3) == 111) r += 10;
	if (sel(&x[0], &x[1]) == 22 && sel(&x[1], &x[1]) == 0) r += 12;
	return r;
}

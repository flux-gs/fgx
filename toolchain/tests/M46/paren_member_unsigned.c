/* An unsigned member widened to long by every spelling of the access: zero
 * extended, whatever route reaches it.  Returns 42. */
struct in { unsigned short v; };
struct m { char *next; unsigned short off; unsigned char c; unsigned long l; struct in in; struct m *self; };
struct m g, arr[2];
struct m *gp;

long a1(x) struct m *x; { return ((long)(*x).off); }
long a2(x) struct m *x; { return ((long)(x)->in.v); }
long a3(x) struct m *x; { return ((long)(x + 0)->off); }
long a4(x) struct m *x; { return ((long)(x)->self->off); }
long a5() { return ((long)(&g)->off); }
long a6() { return ((long)(gp)->off); }
long a7() { return ((long)arr[1].off); }
long a8(x) struct m *x; { return ((long)x[0].in.v); }
long a9(x) struct m *x; { return ((long)(x)[0].off); }
long a10(x) struct m *x; { return ((long)(*x).in.v); }
long a13(x) struct m *x; { return ((long)x->in.v); }
long a11(x) struct m *x; { return ((long)(x)->c + 0L); }
long a12(x) struct m *x; { return ((x)->l + (long)(x)->off); }

int
main()
{
	int r;
	long w;

	w = 0xFF80L;
	g.off = 0xFF80; g.in.v = 0xFF80; g.c = 0x80; g.l = 0x10000L; g.self = &g;
	arr[1].off = 0xFF80;
	gp = &g;
	r = 0;
	if (a1(&g) == w) r += 3;
	if (a2(&g) == w) r += 3;
	if (a3(&g) == w) r += 3;
	if (a4(&g) == w) r += 3;
	if (a5() == w) r += 3;
	if (a6() == w) r += 3;
	if (a7() == w) r += 3;
	if (a8(&g) == w) r += 3;
	if (a9(&g) == w) r += 3;
	if (a10(&g) == w) r += 3;
	if (a11(&g) == 0x80L) r += 3;
	if (a13(&g) == w) r += 3;
	if (a12(&g) == 0x1FF80L) r += 6;
	return (r);
}

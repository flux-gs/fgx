/* A long sum whose right operand reads through a pointer, and a pointer cast to
 * long: the low words carry into the high words.  Returns 42. */
struct m { char *next; unsigned short off; };

struct m g;
unsigned short us = 0xFF80;
long la = 0x005F6B00L;

long
viaptr(x)
	struct m *x;
{
	return ((long)x + (long)x->off);
}

/* The same member through a parenthesized pointer, as a macro's argument is:
 * the parentheses change nothing about its type. */
long
parenlong(x)
	struct m *x;
{
	return ((long)(x)->off);
}

int
parencmp(x)
	struct m *x;
{
	return ((x)->off >= 128);
}

int
parenshift(x)
	struct m *x;
{
	return ((x)->off >> 8);
}

long
plain(a, b)
	long a;
	unsigned short b;
{
	return (a + (long)b);
}

long
viaglobal()
{
	return (la + (long)us);
}

int
main()
{
	long base, want;
	int r;

	r = 0;
	g.off = 0xFF80;
	base = (long)&g;
	want = base + 0xFF80L;
	if (plain(0x005F6B00L, 0xFF80) == 0x00606A80L)
		r += 10;
	if (viaglobal() == 0x00606A80L)
		r += 10;
	if (viaptr(&g) == want)
		r += 10;
	if (parenlong(&g) == 0xFF80L)
		r += 4;
	if (parencmp(&g))
		r += 4;
	if (parenshift(&g) == 0xFF)
		r += 4;
	return (r);
}

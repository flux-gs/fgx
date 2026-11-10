/* A struct passed by value as `*p', through an old-style declaration and
 * through a prototype.  2.11BSD's if_ether.c arpresolve calls
 * in_broadcast(*destip) with destip a struct in_addr *.  K&R A.7.4.3: "If the
 * type of the expression is ``pointer to T,'' the type of the result is T", so
 * the argument is the whole struct, and A.7.3.2: "a copy is made of each
 * argument".  From a parameter, a register parameter, a global pointer, an
 * expression, and a 6-byte struct.  Returns 42. */
struct in_addr { unsigned long s_addr; };
struct six { int a, b, c; };

unsigned long netof();
int sum6();
int proto(struct in_addr in);
struct in_addr *gp;

static int
viaparam(p)
	struct in_addr *p;
{
	return (netof(*p) == 0x04030200L);
}

static int
viareg(p)
	register struct in_addr *p;
{
	return (netof(*p) == 0x04030200L);
}

int main()
{
	struct in_addr v, w[2];
	struct six t, *tp = &t;
	int bad = 0;

	v.s_addr = 0x04030201L;
	w[1] = v;
	gp = &v;
	t.a = 1; t.b = 2; t.c = 3;
	if (!viaparam(&v)) bad |= 1;
	if (!viareg(&v)) bad |= 2;
	if (netof(*gp) != 0x04030200L) bad |= 4;
	if (netof(*(w + 1)) != 0x04030200L) bad |= 8;
	if (sum6(*tp) != 6) bad |= 16;
	if (proto(*gp) != 0x0201) bad |= 32;
	if (v.s_addr != 0x04030201L) bad |= 64;
	return bad ? bad : 42;
}

unsigned long
netof(in)
	struct in_addr in;
{
	in.s_addr &= 0xFFFFFF00L;	/* a copy: the caller's is untouched */
	return (in.s_addr);
}

int
sum6(x)
	struct six x;
{
	return (x.a + x.b + x.c);
}

int
proto(struct in_addr in)
{
	return ((int)(in.s_addr & 0xFFFFL));
}

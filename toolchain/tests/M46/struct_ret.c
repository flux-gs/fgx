/* A function returning a struct by value, as 2.11BSD's in.c returns a
 * struct in_addr from in_makeaddr().  K&R A.10.1: "A function may return an
 * arithmetic type, a structure, a union, a pointer, or void".  The caller
 * passes a hidden pointer to a temporary of its own, so two calls in one
 * expression each see their own value, as must a recursive call and a call
 * through a function pointer, and a value read through a pointer.
 * Returns 42. */
struct pt {
	int x, y;
	long z;
};

struct pt mk();

struct pt
mk(a, b)
	int a, b;
{
	struct pt p;

	p.x = a;
	p.y = b;
	p.z = 100000L;
	return (p);
}

struct pt
sum(n)
	int n;
{
	struct pt r;

	if (n == 0)
		return (mk(0, 0));
	r = sum(n - 1);
	r.x += n;
	return (r);
}

/* The value of `*p' is the struct p points to, as in.c's in_makeaddr
 * returns `*(struct in_addr *)&addr'. */
struct pt
viap(p)
	struct pt *p;
{
	return (*p);
}

struct pt
viacast(q)
	struct pt q;
{
	return (*(struct pt *)&q);
}

int main()
{
	struct pt s, (*fp)();
	int i;

	if (mk(1, 2).x + mk(3, 4).y != 5)
		return (1);
	s = mk(10, 20);
	if (s.x != 10 || s.y != 20 || s.z != 100000L)
		return (2);
	fp = mk;
	if ((*fp)(5, 6).y != 6 || fp(7, 8).x != 7)
		return (3);
	if (sum(4).x != 10)
		return (4);
	s = mk(13, 14);
	if (viap(&s).y != 14 || viacast(s).x != 13)
		return (5);
	i = mk(30, 12).x + mk(0, 12).y;
	mk(9, 9);
	return (i);
}

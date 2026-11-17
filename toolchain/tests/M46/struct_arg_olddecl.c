/* A struct passed by value to a function declared the old way, or defined later,
 * so nothing at the call says the parameter is a struct.  2.11BSD's in.h declares
 * `u_long in_netof();' and route.c's inet_hash calls in_netof(sin->sin_addr).
 * K&R A.7.3.2: "a copy is made of each argument; all argument-passing is strictly
 * by value."  From a variable, `.', `->', a function pointer, a 6-byte struct, one
 * between other arguments, and one read back by va_arg.  Returns 42. */
#include <stdarg.h>
struct in_addr { unsigned long s_addr; };
struct sockaddr_in { short sin_family; unsigned short sin_port; struct in_addr sin_addr; };
struct six { int a, b, c; };

unsigned long netof();
int sum6(), mid();
int vsum(int n, ...);

int main()
{
	struct sockaddr_in s, *sp = &s;
	struct in_addr v;
	struct six t;
	unsigned long (*fp)();
	int bad = 0;

	v.s_addr = 0x04030201L;
	s.sin_addr = v;
	t.a = 1; t.b = 2; t.c = 3;
	fp = netof;
	if (netof(v) != 0x04030200L) bad |= 1;
	if (netof(s.sin_addr) != 0x04030200L) bad |= 2;
	if (netof(sp->sin_addr) != 0x04030200L) bad |= 4;
	if ((*fp)(sp->sin_addr) != 0x04030200L) bad |= 8;
	if (sum6(t) != 6) bad |= 16;
	if (mid(7, v, 9) != 7 + 1 + 9) bad |= 32;
	if (vsum(1, v, 5) != 1 + 1 + 5) bad |= 128;
	v.s_addr = 0L;
	if (s.sin_addr.s_addr != 0x04030201L) bad |= 64;
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
mid(a, in, b)
	int a;
	struct in_addr in;
	int b;
{
	return (a + (int)(in.s_addr & 0xFF) + b);
}

int
vsum(int n, ...)
{
	va_list ap;
	struct in_addr in;
	int r;

	va_start(ap, n);
	in = va_arg(ap, struct in_addr);
	r = n + (int)(in.s_addr & 0xFF) + va_arg(ap, int);
	va_end(ap);
	return (r);
}

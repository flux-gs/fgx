/* Whole-struct assignment into an array element, as 2.11BSD's ip_input.c
 * saves a source route: `ip_srcrt.route[i] = dst;' with route an array of
 * struct in_addr.  K&R A.7.17: in simple assignment "both operands are
 * structures or unions of the same type" is one of the permitted cases,
 * whatever lvalue designates the left one.  Covers a global's array
 * member, a local array, and an array member reached through a pointer,
 * with a struct array element on the right; the neighbors must be
 * untouched.  An element also passes by value as an argument.  Returns 42. */
struct in_addr {
	unsigned long s_addr;
	int pad;
};

struct {
	int nhops;
	struct in_addr route[4];
} ip_srcrt;

static int
padof(x)
	struct in_addr x;
{
	return (x.pad);
}

int main()
{
	struct in_addr s, a[3];
	int i;
	struct { int n; struct in_addr route[4]; } *p;

	i = 1;
	p = (void *)&ip_srcrt;
	s.s_addr = 0x12345678L;
	s.pad = 7;
	a[0].s_addr = a[2].s_addr = 0;
	ip_srcrt.route[0].s_addr = ip_srcrt.route[2].s_addr = ip_srcrt.route[3].s_addr = 0;

	ip_srcrt.route[i] = s;
	a[i] = s;
	p->route[i + 1] = a[i];

	if (ip_srcrt.route[1].s_addr != 0x12345678L || ip_srcrt.route[1].pad != 7)
		return (1);
	if (a[1].s_addr != 0x12345678L || a[0].s_addr != 0 || a[2].s_addr != 0)
		return (2);
	if (ip_srcrt.route[2].s_addr != 0x12345678L || ip_srcrt.route[2].pad != 7)
		return (3);
	if (ip_srcrt.route[0].s_addr != 0 || ip_srcrt.route[3].s_addr != 0)
		return (4);
	if (padof(a[i]) != 7 || padof(p->route[i + 1]) != 7)
		return (5);
	return (42);
}

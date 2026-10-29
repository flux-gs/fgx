/* A pointer's element type carries its signedness into every way of
 * reading through it (K&R A.7.3.1: "E1[E2] is identical (by definition) to
 * *((E1)+(E2))", so p[i], *(p+i) and an array's decayed name read the
 * same object).  An unsigned short read through a pointer and widened to
 * long must zero-extend (A.6.2); taking the INDEX's signedness, or none,
 * sign-extended $F248 to $FFFFF248.  Returns 42. */
unsigned short a[2] = { 0xF248, 1 };

long
viaptr(o, i)
unsigned short *o;
int i;
{
	return o[i];
}

int
main()
{
	unsigned short *p;
	long v;
	int r;

	p = a;
	r = 0;
	v = p[0];		if (v == 0xF248L) r += 10;
	v = *(p + 0);		if (v == 0xF248L) r += 10;
	v = a[0];		if (v == 0xF248L) r += 10;
	v = viaptr(p, 0);	if (v == 0xF248L) r += 12;
	return r;
}

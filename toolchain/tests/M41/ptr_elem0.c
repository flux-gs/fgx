/* Storing an int 0 into a pointer element writes the whole pointer (K&R
 * A.6.6: the constant 0 converts to a null pointer of the element's type).
 * A word store left the bank and pad bytes of `(*(char ***)&x)[i] = 0' as
 * they were, so the "null" entry kept stale memory's bank.  Returns 42. */
union cell { char *p[2]; long l[2]; };
union cell c;
long x;

int
main()
{
	int r;

	c.l[0] = 0x55E1191CL;
	c.l[1] = 0x55E1191CL;
	x = (long)c.p;
	(*(char ***)&x)[1] = 0;
	r = 0;
	if (c.l[1] == 0L)		r += 20;
	if (c.l[0] == 0x55E1191CL)	r += 22;
	return r;
}

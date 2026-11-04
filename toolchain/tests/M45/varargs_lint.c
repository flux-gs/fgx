/* A definition under lint's VARARGS1 called with more arguments than it
 * names, the way 2.11BSD ftp's `command(fmt, args)' takes its printf
 * arguments: the parameters past the first walk up from the address of the
 * last named one.  K&R A.7.3.2 says "the number of arguments must be the
 * same" only of a new-style declaration; under an old-style one a mismatch
 * is undefined, and VARARGS1 states that the callee expects it.  As in
 * ftp, a conditional stands between the marker and the definition.
 * Returns 42. */
/*VARARGS1*/
#ifdef notdef
sum(n, va_alist)
#else
sum(n, args)
#endif
	int n;
{
	int *ap, t;

	ap = &args;
	t = 0;
	while (n-- > 0)
		t += *ap++;
	return (t);
}

int main()
{
	return sum(3, 20, 15, 7);
}

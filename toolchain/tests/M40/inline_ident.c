/* `inline' as an ordinary name, the way 2.11BSD cat.c uses it: a global
 * declared after other names, assigned at statement start, compared in an
 * expression and in a parenthesised one.  K&R A.2.4 does not reserve it.
 * Returns 42 when every use reads the variable. */
int	spaced, col, lno, inline, ibsize;

int
main()
{
	int r;

	r = 0;
	inline = 0;
	if (inline == 0)
		r += 20;
	inline = 1;
	if ((inline) == 1)
		r += 22;
	return r;
}

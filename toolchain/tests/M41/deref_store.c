/* Stores through `*E' where E is a computed pointer, not a name: `**pp',
 * `*(p + 1)', `**(double **)ip' (2.11BSD doscan.c's _innum).  K&R 2nd ed
 * A.7.4.3: unary * "is an lvalue if the operand is a pointer to an object of
 * arithmetic, structure, union, or pointer type"; A.7.17: "The type of an
 * assignment expression is that of its left operand, and the value is the
 * value stored in the left operand after the assignment has taken place."
 * Covered: int, long, float, double and long long targets, as statements
 * and as the value of an expression, with `=' and `+=', and with a call as
 * the right operand.  A failing check returns its number; all passing
 * returns 42. */
static double dv[3];
static double *dp = &dv[0];
static double **dpp = &dp;
static long long qv[2];
static long long *qp = &qv[0];
static long long **qpp = &qp;
static int iv[3];
static int *ip = &iv[0];
static int **ipp = &ip;
static long lv[2];
static long *lp = &lv[0];
static float fv[2];
static float *fp = &fv[0];

static double
half(d)
	double d;
{
	return d / 2;
}

int
main()
{
	double d, e;
	long long q;
	int i, **cast;
	float f;

	d = 1.5;
	**dpp = d;			if (dv[0] != 1.5) return 1;
	*(dp + 1) = 2.25;		if (dv[1] != 2.25) return 2;
	**dpp += 0.5;			if (dv[0] != 2.0) return 3;
	e = (**dpp = 3.0) + 1;		if (e != 4.0 || dv[0] != 3.0) return 4;
	*(dp + 2) = half(5.0);		if (dv[2] != 2.5) return 5;
	cast = (int **)&dp;
	**(double **)cast = half(9.0);	if (dv[0] != 4.5) return 6;
	**(double **)cast = 7;		if (dv[0] != 7.0) return 7;

	q = 0x123456789ALL;
	**qpp = q;			if (qv[0] != 0x123456789ALL) return 8;
	*(qp + 1) = q + 1;		if (qv[1] != 0x123456789BLL) return 9;

	i = (**ipp = 7);		if (i != 7 || iv[0] != 7) return 10;
	i = (*(ip + 1) = 9);		if (i != 9 || iv[1] != 9) return 11;
	*(lp + 1) = 70000L;		if (lv[1] != 70000L) return 12;
	f = (*(fp + 1) = 0.5f);		if (f != 0.5f || fv[1] != 0.5f) return 13;
	*(fp + 1) = half(3.0);		if (fv[1] != 1.5f) return 14;
	return 42;
}

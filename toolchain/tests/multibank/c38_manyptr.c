/* c38_manyptr.c — many live far-pointer values in one expression.
 *
 * P3-2 model edge: FPR pressure.  Six heap pointers marshalled in one
 * call (each arg a data-bank-array element deref), plus a ternary whose
 * pointer RESULT is chosen by comparing two other pointers — the
 * control-flow join rule (both arms must deposit into the same
 * register) and the spill path if the band is shallow. */
extern char *malloc(unsigned long);   /* WIDE (M-4): a K&R empty-paren decl pushes 16-bit args where malloc reads a 32-bit size */

char *c38_p[6];                  /* data-bank array of heap ptrs */

static int
c38_sum6(a, b, c, d, e, f)
	char *a, *b, *c, *d, *e, *f;
{
	return *a + *b + *c + *d + *e + *f;
}

int
c38_check(void)
{
	int i;
	for (i = 0; i < 6; i++) {
		c38_p[i] = malloc(2);
		if (!c38_p[i]) return 0;
		*c38_p[i] = i + 1;
	}
	/* six pointer args in one marshal */
	if (c38_sum6(c38_p[0], c38_p[1], c38_p[2],
	             c38_p[3], c38_p[4], c38_p[5]) != 21) return 0;
	/* deref of a ternary-selected pointer, condition itself a ptr compare */
	if (*(c38_p[0] == c38_p[1] ? c38_p[2] : c38_p[3]) != 4) return 0;
	if (*(c38_p[0] != c38_p[1] ? c38_p[2] : c38_p[3]) != 3) return 0;
	return 1;
}

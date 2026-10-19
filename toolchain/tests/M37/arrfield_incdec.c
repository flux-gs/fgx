/* arrfield_incdec: `++'/`--' on an ELEMENT of an array member, and `op=' on
 * one reached through an array subscript.  apple/fgx#394.
 *
 * `s.a[i]++' was refused on every base while `s.a[i] = v' compiled and, on two
 * of the three bases, `s.a[i] += 1' did too -- so the address arithmetic and
 * the read-modify-write both already existed and only the routing to them was
 * missing.  K&R A.7.17 (p.169) supplies the equivalence that makes the rewrite
 * exact rather than approximate: "An expression of the form E1 op= E2 is
 * equivalent to E1 = E1 op (E2) except that E1 is evaluated only once", and
 * A.7.3.4 says `++' increments "by 1".  In STATEMENT context the postfix
 * expression's value is discarded, so `E++;' and `E += 1;' are the same
 * statement.
 *
 * IT CHECKS VALUES, NOT COMPILATION.  A desugar that reached the wrong element
 * -- a dropped field offset, an unscaled index, a byte where a word belongs --
 * compiles perfectly and runs.  So every arm bumps ONE element and then holds
 * its NEIGHBOURS to their own values; landing next door takes the arm down.
 *
 * THE BYTE AND WORD CASES ARE BOTH HERE because the element stride is what a
 * routing mistake gets wrong first: `d' is char[] and `w' is int[], and an
 * index scaled for the wrong one lands on a neighbour rather than failing.
 *
 * 6 + 6 + 6 + 6 + 6 + 6 + 6 = 42. */

struct sl {
	int  t;
	char d[4];
	int  w[4];
};

static struct sl vs[3];
static struct sl obj;

int
main()
{
	struct sl *p;
	int i, r = 0;

	/* Plain base, int array, CONSTANT index.  `t' and the two neighbouring
	 * elements are the guard: a lost field offset lands on `t'. */
	obj.t = 10;
	obj.w[0] = 20; obj.w[1] = 30; obj.w[2] = 40;
	obj.w[1]++;
	if (obj.w[1] == 31 && obj.w[0] == 20 && obj.w[2] == 40 && obj.t == 10)
		r += 6;

	/* Plain base, int array, RUNTIME index -- the index must be scaled. */
	i = 2;
	obj.w[i]--;
	if (obj.w[2] == 39 && obj.w[1] == 31 && obj.w[0] == 20) r += 6;

	/* Plain base, CHAR array: stride 1, not 2. */
	obj.d[0] = 'a'; obj.d[1] = 'b'; obj.d[2] = 'c';
	obj.d[1]++;
	if (obj.d[1] == 'c' && obj.d[0] == 'a' && obj.d[2] == 'c') r += 6;

	/* Arrow base, int array. */
	p = &obj;
	p->w[0]++;
	if (obj.w[0] == 21 && obj.w[1] == 31) r += 6;

	/* Arrow base, char array, runtime index. */
	i = 2;
	p->d[i]--;
	if (obj.d[2] == 'b' && obj.d[1] == 'c' && obj.d[0] == 'a') r += 6;

	/* INDEXED base with a compound operator -- `vs[k].w[j] += n'.  This one
	 * was refused while the plain and arrow spellings of it compiled, so
	 * the element it lands on is worth checking against both neighbouring
	 * STRUCTS as well as the neighbouring elements. */
	vs[0].w[1] = 100; vs[0].w[2] = 200;
	vs[1].w[1] = 300;
	vs[0].w[1] += 7;
	if (vs[0].w[1] == 107 && vs[0].w[2] == 200 && vs[1].w[1] == 300) r += 6;

	/* And the indexed base with a RUNTIME struct index, so the outer
	 * subscript is scaled by the struct's size rather than the member's. */
	i = 1;
	vs[i].w[1] -= 50;
	if (vs[1].w[1] == 250 && vs[0].w[1] == 107) r += 6;

	return r;				/* 42 */
}

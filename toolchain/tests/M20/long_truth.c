/* M20: a truth test on a 32-bit value must weigh the HIGH word (issue #8).
 *
 * `if (v)` / `!v` / `v ? :` tested only the LOW word, because A carries the
 * low half and _fcc_long_hi the high half.  So any long that is a multiple of
 * 65536 -- low word zero, high word non-zero -- read as FALSE, while `v != 0`
 * went through _fcc_long_eq, compared all 32 bits, and read the same value as
 * TRUE.  Two constructs, one value, opposite answers.
 *
 * Every case has a ZERO twin: a fix that weighs only the high word, or gets
 * the polarity backwards, makes genuine zeros read true -- worse than the bug.
 *
 * Floats carry the extra trap that IEEE-754 NEGATIVE ZERO is $80000000, which
 * compares equal to 0.0, so `if (-0.0)` must be FALSE even though a bit of the
 * high word is set.
 *
 * Returns 42 on success; otherwise 1..n identifying the first failing case.
 */

long lt_ret();

long lt_hi = 65536L;          /* lo=$0000 hi=$0001 -- the defect's shape */
long lt_zero = 0L;
long lt_lo = 42L;             /* lo=$002A hi=$0000 -- the case that always worked */
double lt_negzero = -0.0;
double lt_fone = 1.0;

int
main()
{
	int ok;

	/* Control: equality already weighs all 32 bits.  If these fail the
	 * fixture is not testing what it thinks it is. */
	if (lt_hi == 0) return 1;
	if (lt_zero != 0) return 2;

	/* The defect: the truth test must AGREE with the control. */
	if (!lt_hi) return 3;
	ok = 0;
	if (lt_hi) ok = 1;
	if (!ok) return 4;
	if ((lt_hi ? 1 : 0) != 1) return 5;
	if (!(lt_hi && lt_lo)) return 6;
	if (!(lt_hi || lt_zero)) return 7;

	/* The zero twin must not regress. */
	if (lt_zero) return 8;
	ok = 0;
	if (!lt_zero) ok = 1;
	if (!ok) return 9;
	if ((lt_zero ? 1 : 0) != 0) return 10;
	if (lt_zero && lt_lo) return 11;

	/* The low-word-only case that worked before must still work. */
	if (!lt_lo) return 12;
	if (lt_lo ? 0 : 1) return 13;

	/* Loops: the condition arms of while/for/do walk separately. */
	{
		int spins;
		long v;

		spins = 0;
		v = lt_hi;
		while (v) {
			spins++;
			v = 0L;
		}
		if (spins != 1) return 14;

		spins = 0;
		for (v = lt_hi; v; v = 0L)
			spins++;
		if (spins != 1) return 15;

		spins = 0;
		v = lt_hi;
		do {
			spins++;
			v = 0L;
		} while (v);
		if (spins != 1) return 16;

		/* A zero must not enter the loop.  Bounded so a regression is a
		 * wrong exit code rather than a hang. */
		spins = 0;
		v = lt_zero;
		while (v) {
			spins++;
			if (spins > 3) break;
		}
		if (spins != 0) return 17;
	}

	/* Float: -0.0 has the sign bit set but IS zero. */
	if (lt_negzero != 0.0) return 18;      /* control */
	if (lt_negzero) return 19;             /* must be FALSE despite bit 31 */
	if (!(!lt_negzero)) return 20;
	if (!lt_fone) return 21;               /* an ordinary non-zero float */
	if ((lt_fone ? 1 : 0) != 1) return 22;

	/* A long arriving as a FUNCTION RETURN rather than a global load.  The
	 * analogous pointer case is what broke the earlier attempt at the #6
	 * fix, so cover the shape here rather than assume the load path
	 * generalises. */
	if (!lt_ret()) return 23;
	if (lt_ret() == 0) return 24;          /* control */
	if ((lt_ret() ? 1 : 0) != 1) return 25;

	return 42;
}

long
lt_ret()
{
	return 65536L;                         /* lo=$0000, hi=$0001 */
}

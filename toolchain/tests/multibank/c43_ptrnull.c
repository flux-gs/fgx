/* c43_ptrnull.c -- a far-pointer TRUTH TEST must weigh the bank byte (#6).
 *
 * `if (p)`, `!p`, `p ? a : b`, `p && q` and `p || q` compiled to a bare
 * `CMP #0` against the OFFSET word alone, so a pointer at bank:0000 -- a
 * NON-ZERO bank with a zero offset -- read as NULL.  Meanwhile `p != 0`
 * goes through emit_fpr_cmp, which compares the offset word AND the bank
 * byte, and read the very same pointer as non-NULL.  Two constructs, one
 * pointer, opposite answers: that disagreement is what this guards.
 *
 * Reachable, not hypothetical: the kernel arena's large-block path hands back
 * dedicated blocks at bank:0000.
 *
 * HOW THE SUBJECT IS BUILT, and why it changed (2026-08-04, apple/fgx#12).
 * This case used to build its bank:0000 pointer by casting a RUNTIME int zero,
 * on the rule that a runtime int reconstitutes into the DATA bank.  That rule
 * now has an exception: offset 0 is the NULL pointer and keeps bank 0, because
 * 2.11BSD sh assigns a runtime zero to a pointer for an unset positional
 * parameter (macro.c:86, `v = (... : (dolg=0))`, on every `$` expansion) and a
 * DBR:0000 "null" read as TRUE there and hung the shell.  So `(char *)0` cast
 * from a runtime int is now a genuine NULL and can no longer build this
 * subject.
 *
 * It is built from a runtime LONG instead: the long->pointer cast takes the
 * bank from the high word unconditionally, so `(char *)c43_opaque_long(
 * 0x00010000L)` is bank 1, offset 0 -- deterministic, and still with no
 * reliance on allocator placement, which is the property that matters here.
 * Do NOT "simplify" it back to an int cast: that silently turns every
 * NON-null assertion below into a null one and the whole case goes vacuous.
 *
 * Both polarities matter.  The earlier attempt at this fix was reverted
 * because it read a load-path side-effect cell that held a STALE bank, so
 * genuinely-NULL pointers began reading NON-null -- strictly worse than the
 * bug.  Every case below therefore has a NULL twin: a fix that trades one
 * direction for the other fails here rather than shipping.
 */

extern int c43_opaque();      /* K&R: defeats the compile-time-const cast arm */
extern long c43_opaque_long();        /* ditto, for the bank-carrying long cast */
extern char *malloc(unsigned long);   /* WIDE (M-4): K&R empty-paren pushes 16-bit args */

struct c43s { char *f; int v; };

char c43_obj;
struct c43s c43_st;

/* A genuine NULL arriving as a FUNCTION RETURN rather than a literal.  This
 * is the reverted fix's exact failure mode: it read a load-path side-effect
 * cell that a returned pointer never populates, so the stale bank left there
 * made this read NON-null and the code dereferenced it. */
static char *
c43_null_ret()
{
	return (char *)0;
}

static int
c43_seven()
{
	return 7;
}

/* Returns its argument.  Called through an extern declaration so the cast
 * operand is a RUNTIME value -- a compile-time constant would reconstitute
 * into bank 0 and quietly build the wrong kind of pointer. */
int
c43_opaque(x)
	int x;
{
	return x;
}

/* Returns its long argument.  Called through an extern declaration so the cast
 * operand is a RUNTIME long: the long->pointer cast lays the high word into the
 * bank byte, which is what makes an arbitrary bank:offset pointer constructible
 * without depending on where the allocator happens to put things. */
long
c43_opaque_long(x)
	long x;
{
	return x;
}

int
c43_check(void)
{
	char *z;              /* bank:0000 -- NON-null */
	char *n;              /* a genuine NULL */
	char *g;              /* an ordinary valid pointer */
	char *p;              /* a heap pointer */
	char *q;              /* scratch for assign-in-condition */
	int ok;
	int spins;

	z = (char *)c43_opaque_long(0x00010000L);   /* bank 1, offset 0 */
	n = (char *)0;
	g = &c43_obj;

	/* The control: equality already weighs both halves and is correct.
	 * If these two fail, the fixture is not building the pointer it
	 * thinks it is and every result below would be vacuous. */
	if (z == 0) return 0;
	if (n != 0) return 0;

	/* The defect: each truth test must AGREE with the control above. */
	if (!z) return 0;                       /* `!p` */
	ok = 0;
	if (z) ok = 1;                          /* `if (p)` */
	if (!ok) return 0;
	if ((z ? 1 : 0) != 1) return 0;         /* ternary condition */
	if (!(z && g)) return 0;                /* && with the ptr on the left */
	if (!(g && z)) return 0;                /* && with the ptr on the right */
	if (!(z || n)) return 0;                /* || with the ptr on the left */
	if (!(n || z)) return 0;                /* || with the ptr on the right */

	/* The converse must not regress: a real NULL still reads false. */
	if (n) return 0;
	ok = 0;
	if (!n) ok = 1;
	if (!ok) return 0;
	if ((n ? 1 : 0) != 0) return 0;
	if (n && g) return 0;
	if (!(n || g)) return 0;

	/* while(): the loop-safepoint path, both polarities. */
	spins = 0;
	while (z) {
		spins++;
		z = (char *)0;
	}
	if (spins != 1) return 0;

	/* Rebuild the bank:0000 pointer for the remaining loop forms. */
	z = (char *)c43_opaque_long(0x00010000L);   /* bank 1, offset 0 */

	/* for(): the same condition arm, a different statement walker. */
	spins = 0;
	for (; z; z = (char *)0)
		spins++;
	if (spins != 1) return 0;

	z = (char *)c43_opaque_long(0x00010000L);   /* bank 1, offset 0 */

	/* do/while(): the condition is walked AFTER the body. */
	spins = 0;
	do {
		spins++;
		z = (char *)0;
	} while (z);
	if (spins != 1) return 0;

	/* A NULL must not enter the same loops at all.  Bounded on purpose:
	 * an unbounded spin would report the regression as a HANG (no =MBEND
	 * marker), which reads as a harness failure rather than a red case. */
	spins = 0;
	while (n) {
		spins++;
		if (spins > 3) break;
	}
	if (spins != 0) return 0;
	for (; n; ) {
		spins++;
		if (spins > 3) break;
	}
	if (spins != 0) return 0;

	/* A NULL that arrives as a RETURN VALUE, not a literal -- the precise
	 * case the reverted fix broke.  If a fix ever reads a stale side-effect
	 * bank again instead of this expression's own carrier, this goes red
	 * BEFORE the failsafe group does. */
	q = c43_null_ret();
	if (q) return 0;
	if (q != 0) return 0;
	if (!(!q)) return 0;
	if ((q ? 1 : 0) != 0) return 0;

	/* Assignment-in-condition: the result must be the assigned pointer's
	 * full value, not a re-read of some other carrier. */
	p = malloc(4);
	if (!p) return 0;                       /* a live allocation reads true */
	ok = 0;
	if ((q = p)) ok = 1;
	if (!ok) return 0;
	ok = 0;
	if ((q = (char *)0)) ok = 1;
	if (ok) return 0;                       /* assigning NULL reads false */

	/* Short-circuit guarding a DEREF -- the shape that actually appears in
	 * ported code (`if (p && p->field)`).  The && must not evaluate the RHS
	 * when the LHS is NULL, and must evaluate it when the LHS is bank:0000. */
	c43_st.f = p;
	c43_st.v = 5;
	if (!(&c43_st && c43_st.v == 5)) return 0;
	if (c43_null_ret() && c43_st.v == 5) return 0;   /* RHS must not run */

	/* Ternary with a pointer condition NESTED in another ternary. */
	z = (char *)c43_opaque_long(0x00010000L);   /* bank 1, offset 0 */
	if ((z ? (p ? 1 : 2) : 3) != 1) return 0;
	if ((q ? (p ? 1 : 2) : 3) != 3) return 0;

	/* Function pointers: ISPTR is true for them, so they take the same
	 * path.  A function at offset 0 of its code bank would read NULL under
	 * the old test exactly as a data pointer did. */
	{
		int (*fp)();
		fp = c43_seven;
		if (!fp) return 0;
		if ((fp ? 1 : 0) != 1) return 0;
		if (fp() != 7) return 0;
		fp = 0;
		if (fp) return 0;
		if (!(!fp)) return 0;
	}

	return 1;
}

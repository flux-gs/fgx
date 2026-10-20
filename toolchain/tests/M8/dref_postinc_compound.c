/* M8: COMPOUND assignment through a deref whose pointer also ++/--s --
 * `*dp++ &= MASK` (tcsh sh.misc's `while (*dp++ &= TRIM)`).
 *
 * The point is that the pointer must advance EXACTLY ONCE.  K&R A.7.17: in
 * `E1 op= E2` the lvalue E1 is evaluated only once, so this cannot be
 * desugared to `*dp++ = *dp++ & MASK` -- that steps twice and masks every
 * OTHER element.  The while-loop legs below fail loudly if that happens:
 * bytes[1] and bytes[2] would come back unmasked.
 *
 * Legs: post-increment compound (the motivating shape), PRE-increment
 * compound (the pointer is bumped before the deref), and `>>=` on an
 * UNSIGNED CHAR leaf, which K&R A.6.1 promotes to int before the shift: the
 * byte's value is 0..255, so the arithmetic shift gives the logical one's
 * answer.  Returns 42.
 */
unsigned char bytes[4];
int words[2];

int main()
{
	unsigned char *bp;
	int *ip;
	int r = 0;

	bytes[0] = 0xC1;
	bytes[1] = 0xC2;
	bytes[2] = 0x83;
	bytes[3] = 0x00;		/* terminates the while */

	bp = bytes;
	while (*bp++ &= 0x7F)		/* masks each element exactly once */
		;

	if (bytes[0] == 0x41) r += 10;
	if (bytes[1] == 0x42) r += 10;	/* 0 if the pointer double-stepped */
	if (bytes[2] == 0x03) r += 10;

	/* PRE-increment leg, kept in EXPRESSION context on purpose: this fix is
	 * in build_assign, and the STATEMENT form `*++ip += 5;` goes through the
	 * statement dispatcher, which still accepts '=' only.  Testing the value
	 * of the whole expression also pins that a compound deref-store LEAVES
	 * its result (K&R A.7.17: the value is the value stored). */
	words[0] = 1;
	words[1] = 2;
	ip = words;
	if ((*++ip += 5) == 7) r += 6;	/* pre-inc: hits words[1] -> 7 */
	if (words[1] != 7) r -= 100;	/* and it really landed in memory */

	bp = bytes;			/* bytes[0] is 0x41 == 65 */
	*bp >>= 1;			/* promoted to int (A.6.1): 64 >> 1 = 32 */
	if (bytes[0] == 32) r += 6;

	return r;
}

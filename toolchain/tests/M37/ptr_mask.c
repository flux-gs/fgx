/* ptr_mask: `&', `^' and `|' with a POINTER operand -- masking an address,
 * which fcc accepts as BSD code does (the offset word is the operand).
 *
 * `m & p' compiled to the AND and then stored p's OFFSET over the result: the
 * pointer operand was left live in an expression register, and the store took
 * that register as the value.  `p & m' stopped the compiler outright, with an
 * internal register-leak error.  Both operand positions are here, and the
 * mask is chosen so that the result, the mask and the offset all differ.
 *
 * 7 arms x 6 = 42. */

static char buf[64];

int
main()
{
	char *p;
	int m, x, off, r = 0;

	p = &buf[21];
	off = (int)p;
	m = 0x0F;

	x = m & p;
	if (x == (off & 0x0F)) r += 6;

	x = p & m;
	if (x == (off & 0x0F)) r += 6;

	x = p | 1;
	if (x == (off | 1)) r += 6;

	x = 0x5A ^ p;
	if (x == (0x5A ^ off)) r += 6;

	/* In a condition, where the value is tested rather than stored. */
	if ((p & 1) == (off & 1)) r += 6;

	/* The pointer itself is unchanged by any of it. */
	if (p == &buf[21]) r += 6;

	/* And an int is still masked by an int. */
	x = m & 0x3C;
	if (x == 0x0C) r += 6;

	return r;				/* 42 */
}

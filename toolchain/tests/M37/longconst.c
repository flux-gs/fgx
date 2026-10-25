/* A constant right operand of a long operation, widened at its own type
 * (K&R A.6.5): 0xFFFF is an unsigned int and zero-extends, -1 is an int
 * and sign-extends, 70000L is already long.  The operations are binary
 * and compound.  Returns 42 when every result matches. */
long l = 0x12345678L;

int main()
{
	long m;
	int r;

	r = 0;
	if ((l & 0xFFFF) == 0x5678L) r += 5;	/* zero-extended mask */
	if ((l & -1) == l) r += 5;		/* sign-extended mask */
	if (l + -2 == 0x12345676L) r += 5;
	if ((l >> 4) == 0x01234567L) r += 5;
	if (l / 70000L == 4363L && l % 10 == 6) r += 5;
	m = l;
	m -= -1;				/* sign-extended: +1 */
	m |= 0x8000;				/* zero-extended: bit 15 only */
	if (m == 0x1234D679L) r += 5;
	m = 5;
	m <<= 3;
	if (m == 40 && m > -1 && m < 0xFFFF) r += 6;
	m ^= 0xFFFF;
	if (m == 0xFFD7L) r += 6;
	return r;
}

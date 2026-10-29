/* --signed-char: a char not declared unsigned holds -128..127 (K&R A.4.2:
 * "the available range of values, and especially whether the value is
 * signed, is implementation-dependent").
 * A char read, stored and compared below zero; an unsigned char and an
 * assignment to one stay 0..255.  Returns 42. */
char c = 0xF0;
unsigned char u = 0xF0;
char buf[2] = { 0x80, 0 };

int
main()
{
	char d;
	int r;

	r = 0;
	if (c < 0)		r += 10;
	if (c == -16)		r += 5;
	if (u > 0 && u == 240)	r += 10;
	if (buf[0] == -128)	r += 5;
	if ((d = 0xFF) == -1)	r += 6;
	if ((u = 0xFF) == 255)	r += 6;
	return r;
}

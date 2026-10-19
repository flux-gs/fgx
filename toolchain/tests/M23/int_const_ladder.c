/* M23 (A-1 family): K&R A.2.5.1 integer-constant TYPE ladder.
 *
 * "If it is unsuffixed and decimal, it has the first of these types in which
 *  its value can be represented: int, long int, unsigned long int.  If it is
 *  unsuffixed, octal or hexadecimal, it has the first possible of these types:
 *  int, unsigned int, long int, unsigned long int."
 *
 * So `unsigned int` is a rung for OCTAL/HEX only, and `long int` catches the
 * decimal case.  fcc used to skip both rungs -- a constant was `int` unless it
 * exceeded 65535, and unsigned only with a U suffix.  With a 16-bit int that
 * is a silent wrong-VALUE bug rather than a pedantic one: 0xFFFF was a SIGNED
 * int, so `long a = 0xFFFF` sign-extended through _fcc_long_from_int and
 * stored 0xFFFFFFFF (-1) instead of 65535.  Every bit mask >= 0x8000 widened
 * to a long was wrong, in either radix.
 *
 * Each leg below widens a constant in [0x8000, 0xFFFF] to a long, which is
 * exactly where the ladder used to break.  Returns 42.
 */
long a, b, c, d, e;

int main()
{
	int r = 0;

	a = 0xFFFF;		/* hex     -> unsigned int 65535, zero-extends */
	b = 65535;		/* decimal -> long int 65535                   */
	c = 0177777;		/* octal   -> unsigned int 65535               */
	d = 0x8000;		/* hex     -> unsigned int 32768               */
	e = 0x7FFFL;		/* L suffix -> long int, unaffected            */

	if (a == 65535L) r += 8;
	if (b == 65535L) r += 8;
	if (c == 65535L) r += 8;
	if (d == 32768L) r += 9;
	if (e == 32767L) r += 9;

	return r;		/* 8+8+8+9+9 = 42 */
}

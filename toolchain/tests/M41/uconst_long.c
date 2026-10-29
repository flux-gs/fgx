/* An unsigned int constant in a constant expression widens to long
 * zero-extended (K&R A.2.5.1: a u suffix makes the constant unsigned;
 * A.6.2: unsigned to a wider type preserves the value).  The folded
 * initializer read 65535u as -1.  Returns 42. */
long a = 65535u + 0;
long b[1] = { 0xF000u * 1 };

int
main()
{
	int r;

	r = 0;
	if (a == 65535L)	r += 20;
	if (b[0] == 61440L)	r += 22;
	return r;
}

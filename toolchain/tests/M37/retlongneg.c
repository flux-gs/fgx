/* A negative signed int used as a LONG return value must sign-extend, not
 * zero-extend.  `code_int getcode(){ ...; return -1; }` returned 0x0000FFFF
 * (=65535), so compress(1)'s `while ((code=getcode()) > -1)` never saw EOF
 * and uncompress over-read garbage.  Also check a >16-bit positive return.
 * Exit 42. */
typedef long code_int;
code_int retneg(e)
	int e;
{
	if (e)
		return -1;
	return 65;
}
code_int retbig(void)
{
	return 100000L;
}
int main(void)
{
	if (retneg(1) != -1L)      return 1;
	if (retneg(1) >= 0)        return 2;
	if (retneg(0) != 65L)      return 3;
	if (retbig() != 100000L)   return 4;
	return 42;
}

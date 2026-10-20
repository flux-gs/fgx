/* G49: sizeof(type) usable in a constant expression — array DIMENSIONS and the
 * `N / sizeof(T)` idiom (elvis's `unsigned short n[BLKSIZE/sizeof(unsigned short)]`),
 * plus runtime sizeof of the integer types the is_type gate once rejected
 * (short / unsigned short / long — only char/int/struct/typedef were accepted).
 * Index K is valid iff each dimension evaluated correctly.  -> 42. */
#define BLKSIZE 1024
char  gbuf[sizeof(long) + 1];                  /* global dim: 4 + 1 = 5   */
short hdr[BLKSIZE / sizeof(unsigned short)];    /* 1024 / 2   = 512        */

int main(void)
{
	static int sb[sizeof(int) * 3];         /* static-local dim: 2*3 = 6 */
	int rt;

	gbuf[4]  = 7;                           /* valid iff dim == 5   */
	hdr[511] = 9;                           /* valid iff dim == 512 */
	sb[5]    = 5;                           /* valid iff dim == 6   */
	rt = sizeof(short) + sizeof(unsigned short) + sizeof(long); /* 2+2+4 = 8 */

	if (gbuf[4]  != 7) return 1;
	if (hdr[511] != 9) return 2;
	if (sb[5]    != 5) return 3;
	if (rt       != 8) return 4;
	return 42;
}

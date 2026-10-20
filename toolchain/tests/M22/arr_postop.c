/* Postfix ++/-- on an int/char ARRAY element — tio's `while (widths[len]-- > 0)`.
 * Address-based RMW that yields the OLD value; local & global, byte & word.
 * -> 42. */
int giw[4];
unsigned char gcb[4];

int main(void)
{
	int  liw[4];
	int  i, old, n;

	giw[0] = 5;  old = giw[0]--;   /* old=5, giw[0]=4 */
	if (old != 5)   return 1;
	if (giw[0] != 4) return 2;

	liw[1] = 10; old = liw[1]++;   /* old=10, liw[1]=11 */
	if (old != 10)  return 3;
	if (liw[1] != 11) return 4;

	gcb[2] = 200; old = gcb[2]--;  /* old=200, gcb[2]=199 (byte) */
	if (old != 200) return 5;
	if (gcb[2] != 199) return 6;

	/* the tio idiom: post-dec in a loop condition, OLD value tested */
	giw[3] = 3; n = 0;
	while (giw[3]-- > 0) n++;       /* tests 3,2,1 >0 -> 3 iters; then 0-- */
	if (n != 3) return 7;

	return 42;
}

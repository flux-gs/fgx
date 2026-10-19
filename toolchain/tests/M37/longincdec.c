/* ++/-- on a LONG LOCAL must carry/borrow across the 16-bit word boundary.
 * fcc's generic scalar-local ++/-- only touched the low word, so `long c=0;
 * c--` gave 0x0000FFFF (=65535) not -1 — compress(1) decompress()'s
 * `for(code=255;code>=0;code--)` table-init loop then spun forever. Exit 42. */
typedef long code_int;
int main(void)
{
	register code_int c;
	int iters = 0;

	for (c = 3; c >= 0; c--)          /* the decompress loop shape */
		iters++;
	if (iters != 4)      return 1;    /* 3,2,1,0 */
	if (c != -1L)        return 2;    /* borrow past 0 -> -1            */
	if (c >= 0)          return 3;    /* -1 must read negative          */

	c = 0xFFFFL; c++;
	if (c != 0x10000L)   return 4;    /* carry low->high                */
	c = 0x10000L; c--;
	if (c != 0xFFFFL)    return 5;    /* borrow high->low               */
	c = 0; c--;
	if (c != -1L)        return 6;
	c = -1L; c++;
	if (c != 0L)         return 7;
	return 42;
}

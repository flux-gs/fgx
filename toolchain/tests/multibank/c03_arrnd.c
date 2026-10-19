/* c03_arrnd.c — construct 3: a 2-D data-bank array, FULL decay (a[0][0]) and
 * PARTIAL decay (a[i] -> row pointer).  Partial decay is where emit.c must PHB,
 * not PHK (mole #48).  Values <=0x7F so int compares are signedness-safe. */
int c03_g[2][3] = { {0x11, 0x12, 0x13}, {0x21, 0x22, 0x23} };

static int c03_rowsum(int *r) { return r[0] + r[1] + r[2]; }   /* partial-decay arg */

int c03_check(void)
{
	int full = c03_g[0][0] + c03_g[1][2];        /* full decay: 0x11 + 0x23 */
	int part = c03_rowsum(c03_g[1]);             /* partial decay row 1 */
	return full == 0x34 && part == 0x66;
}

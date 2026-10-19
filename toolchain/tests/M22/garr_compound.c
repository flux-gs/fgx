/* Compound assignment to a GLOBAL array element — `garr[i] op= x`.  The base was
 * loaded as `LDA #gname` (offset only, no bank), so the [_fcc_ptr] deref-load
 * used a stale _fcc_ptr+2 while the DBR-relative store wrote the data bank — a
 * silent wrong value.  Now the load seeds _fcc_ptr+2 = DBR to match.  -> 42. */
unsigned char gbm[8];
int           gv[4];

int main(void)
{
	int i;

	i = 1;
	gv[0] = 40;   gv[0] += 2;        /* 42  */
	gv[i] = 15;   gv[i] &= 6;        /* 6   */
	gbm[0] = 0xF0; gbm[0] |= 0x0F;   /* 255 */
	gbm[2] = 200; gbm[2] -= 100;     /* 100 */

	if (gv[i]   != 6)   return 1;
	if (gbm[0]  != 255) return 2;
	if (gbm[2]  != 100) return 3;
	return gv[0];                    /* 42 */
}

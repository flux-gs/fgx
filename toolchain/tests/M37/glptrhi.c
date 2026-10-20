/* Store/read a `long` with a NONZERO HIGH WORD through a global `long *`.
 * glptrsub only used values < 65536 (high word 0), so it could not catch a
 * high-word drop.  compress stores fcode = ((long)c<<12)+ent into htab[i] --
 * always > 65536 (e.g. 450661 = 0x0006E065) -- and later compares htab[i] ==
 * fcode to find matches.  If the 4-byte transfer through a global long* drops
 * the high word, the compare never matches -> no compression.  Exit 42. */
long  larr[8];
long *lp;

int main(void)
{
	lp = larr;
	lp[2] = 450661L;               /* 0x0006E065 — store via long* pointer   */
	if (larr[2] != 450661L) return 1;   /* read via ARRAY: full 32 bits kept */
	if (lp[2] != 450661L)   return 2;   /* read via POINTER: full 32 bits    */
	if (lp[2] == 450662L)   return 3;   /* compare must see the high word too */
	larr[4] = 0x0006E065L;
	if (lp[4] != 450661L)   return 4;   /* store via array, read via pointer */
	return 42;
}

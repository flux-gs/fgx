/* Long compound-assign regression: the LHS high word is staged in
 * _fcc_long_hi, which every long/float RHS subexpression clobbers, and an
 * int RHS must PROMOTE to 32 bits before the ALU op.  The N_COMPOUND_VAR
 * arm saved only A across the RHS walk and let an int RHS force a 16-bit
 * add — `now += 60` zeroed now's top word, so ls -l compared every mtime
 * against now=60 and took the year branch (H1).  Exit 42. */
long g;
long h = 0x00020005L;

int main(void)
{
	long l;
	int i;

	g = 0x6a520001L;
	g += 60;                        /* global long += int constant */
	if (g != 0x6a52003dL) return 1;
	i = 2;
	g -= i;                         /* global long -= int variable */
	if (g != 0x6a52003bL) return 2;
	g += h;                         /* += long whose high word differs */
	if (g != 0x6a540040L) return 3;
	l = 0x00010000L;
	l += 20;                        /* local long += int constant */
	if (l != 0x00010014L) return 4;
	l += l;                         /* local long += long (self) */
	if (l != 0x00020028L) return 5;
	return 42;
}

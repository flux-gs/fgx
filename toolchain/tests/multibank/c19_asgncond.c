/* c19_asgncond.c — construct 19: assignment-in-condition of a far pointer (the
 * (q = ptr) == 0 Y-clobber mole).  The slot store must not clobber the index
 * used to complete it. */
unsigned char c19_g[4] = { 0x19, 0x29, 0x39, 0x49 };

int c19_check(void)
{
	unsigned char *q;
	if ((q = c19_g) == 0) return 0;     /* assignment-in-condition; q's bank must be right */
	return q[0] == 0x19 && q[1] == 0x29 && q[2] == 0x39 && q[3] == 0x49;
}

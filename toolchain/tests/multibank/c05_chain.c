/* c05_chain.c — construct 5: chained deref-store of a POINTER VALUE through
 * char** (mole #52 shape: *T = *U = q, q a far char*; the OUTER store must keep
 * q's bank).  The deref of c05_a/c05_b proves the stored pointer's bank. */
unsigned char c05_data[4] = { 0x5C, 0x5D, 0x5E, 0x5F };
unsigned char *c05_a, *c05_b;
unsigned char **c05_pa = &c05_a, **c05_pb = &c05_b;

int c05_check(void)
{
	unsigned char *q = c05_data;
	*c05_pa = *c05_pb = q;               /* pointer through char**; outer bank must survive */
	return c05_a == c05_data && c05_b == c05_data
	    && c05_a[0] == 0x5C && c05_b[3] == 0x5F;
}

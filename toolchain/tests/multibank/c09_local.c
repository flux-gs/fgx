/* c09_local.c — construct 9: address-of a LOCAL aggregate yields a far pointer
 * whose bank is the soft-stack bank (not bank 0, not DBR).  Mole #34.  2nd path:
 * a direct read of local[] independent of the buf[] the callee wrote. */
static int c09_fill(unsigned char *buf) { buf[0] = 0x91; buf[1] = 0x92; buf[2] = 0x93; return buf[0] + buf[1] + buf[2]; }

int c09_check(void)
{
	unsigned char local[4];
	int s = c09_fill(local);             /* &local passed as far ptr */
	return s == (0x91 + 0x92 + 0x93) && local[0] == 0x91 && local[2] == 0x93;
}

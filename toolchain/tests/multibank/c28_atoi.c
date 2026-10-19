/* c28_atoi.c — SHIM-population construct (2026-07-05 audit): atoi() on a
 * SOFT-STACK local string.  c_atoi used to hand the bare 16-bit offset to the
 * DBR-relative register-ABI atoi, which then parsed whatever bytes sat at
 * that offset in the DATA bank.  The fixed shim seeds LIBC_DP_LP0 and routes
 * through the bank-aware atol (mirroring c_atol). */
extern int atoi(char *s);

int c28_check(void)
{
	char buf[8];

	buf[0] = '2'; buf[1] = '8'; buf[2] = '6'; buf[3] = '4'; buf[4] = 0;
	return atoi(buf) == 2864;
}

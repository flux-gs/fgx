/* c01_deref.c — construct 1: read a data-bank global through &global from a
 * DIFFERENT code bank.  address-of + deref must emit the global's bank as PHB
 * (=DBR=data seg), not PHK (this code bank).  4-byte tag c01_g; a wrong bank
 * reads this code bank's bytes at c01_g's offset (opcodes/ballast), != the tag.
 *
 * c01_g is the fixture's canonical tag global (the anti-coincidence scan checks
 * every _cNN_g label). */
unsigned char c01_g[4] = { 0x31, 0x51, 0x71, 0x91 };   /* unsigned: high-bit tags compare reliably regardless of fcc char signedness */

int c01_check(void)
{
	unsigned char *p = c01_g;        /* far pointer: offset + bank(PHB) */
	return p[0] == 0x31 && p[1] == 0x51 && p[2] == 0x71 && p[3] == 0x91;
}

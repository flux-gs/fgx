/* c02_arr1d.c — construct 2: a data-bank array decays to a far pointer, passed +
 * indexed.  The array-decay bank must be PHB (data seg). */
unsigned char c02_g[4] = { 0x02, 0x14, 0x28, 0x3C };

static int c02_sum(unsigned char *a) { return a[0] + a[1] + a[2] + a[3]; }

int c02_check(void) { return c02_sum(c02_g) == (0x02 + 0x14 + 0x28 + 0x3C); }

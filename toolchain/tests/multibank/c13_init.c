/* c13_init.c — construct 13: file-scope pointer initializers (loader-patched
 * FGX2_LONG_PTR, not runtime-derived): char *p = &g, char *tbl[] = {"..",..}.
 * Their banks must be the data seg.  Mole: M24 global_ptr_init + far-fnptr-in-init. */
unsigned char c13_g[4] = { 0xD3, 0xD4, 0xD5, 0xD6 };
unsigned char *c13_p = c13_g;                       /* static &global initializer */
char *c13_tbl[3] = { "aa", "bb", "cc" };            /* static string-ptr table */

int c13_check(void)
{
	return c13_p[0] == 0xD3 && c13_p[3] == 0xD6
	    && c13_tbl[0][0] == 'a' && c13_tbl[1][0] == 'b' && c13_tbl[2][1] == 'c';
}

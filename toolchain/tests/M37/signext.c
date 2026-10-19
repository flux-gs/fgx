/* Negative signed int widened to a long must SIGN-extend the high word, not
 * zero-extend it.  fcc used to emit `LDA #0` (or `LDX #0;STX _fcc_long_hi`)
 * for the high word at every int->long store site, so `long m1 = -1` became
 * 0x0000FFFF = 65535.  In compress(1) that made cl_hash's `m1 = -1` sentinels
 * read > 0, so the secondary-hash probe never found an empty slot and looped
 * forever (0-byte .Z / hang).  Exercise every store path fixed:
 *   scalar-local init/assign, int->long widen of a var, struct field in a
 *   local and a global, plain `*p =`, and a long-array element (FPR path).
 * Exit 42 iff all sign-extend; else a distinct code per failing case. */
struct S { long f; };
struct S gs;
long garr[4];

int main(void)
{
	struct S ls;
	long a = -1;                 /* scalar-local init (const)          */
	long b = -5;                 /* scalar-local init (const, != -1)   */
	int  i = -1;
	long c = i;                  /* int -> long widen of a variable    */
	long d;
	long *p = garr;

	d = -1;                      /* scalar-local assign (not init)     */
	ls.f = -7;                   /* struct field in a LOCAL            */
	gs.f = -9;                   /* struct field in a GLOBAL           */
	*p = -3;                     /* plain deref store                  */
	garr[1] = -123;              /* long-array element (FPR path)      */

	if (a != -1L)     return 1;
	if (a >= 0)       return 2;  /* the > 0 test compress relied on    */
	if (b != -5L)     return 3;
	if (c != -1L)     return 4;
	if (d != -1L)     return 5;
	if (ls.f != -7L)  return 6;
	if (gs.f != -9L)  return 7;
	if (*p != -3L)    return 8;
	if (garr[1] != -123L) return 9;
	/* an UNSIGNED int widened to long must still zero-extend */
	{
		unsigned int u = 0xFFFF;
		long z = u;
		if (z != 65535L) return 10;
	}
	return 42;
}

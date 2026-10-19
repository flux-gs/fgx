/* deref_long_rmw: statement-level '++'/'--' of a bare DEREF lvalue whose
 * POINTEE IS A LONG -- `--*len` where len is `off_t *` (novi's buffer.c
 * popone(), which pops one byte off a scratch file and shortens the tracked
 * length through the caller's off_t*).  fcc rejected this outright
 * ("++/-- on '*ptr' of long/struct deref unsupported"); the 16-bit RMW that
 * serves int/char/pointer pointees would silently drop the carry into the
 * high word, so the long pointee routes to emit_long_member_incdec at
 * offset 0 -- the same 32-bit ±1-with-carry path `p->longfield++` uses.
 *
 * Both halves straddle the 16-bit boundary ON PURPOSE, so a 16-bit-only RMW
 * is caught rather than merely a missing one: 0x00010000 - 1 would leave
 * 0x0001FFFF, and 0x0000FFFF + 1 would leave 0x00000000.  Covers the local
 * `long *` and the `long *` PARAMETER (popone's actual shape).
 * K&R A.7.4.3 ('*'), A.7.4.1 (prefix ++/--).  -> 42. */
long g_v;

/* novi buffer.c popone(): the pointee is the caller's off_t. */
void
pop(len)
long *len;
{
	--*len;
}

int
main()
{
	long *p;
	int   r;

	p = &g_v;

	g_v = 0x00010000L;              /* 65536 */
	--*p;                           /* 65535; 16-bit RMW -> 0x0001FFFF */
	r = (g_v == 0x0000FFFFL) ? 14 : 0;

	g_v = 0x0000FFFFL;              /* 65535 */
	++*p;                           /* 65536; 16-bit RMW -> 0x00000000 */
	r += (g_v == 0x00010000L) ? 14 : 0;

	g_v = 0x00010000L;              /* through a long* PARAMETER */
	pop(&g_v);
	r += (g_v == 0x0000FFFFL) ? 14 : 0;

	return r;                       /* 14 * 3 = 42 */
}

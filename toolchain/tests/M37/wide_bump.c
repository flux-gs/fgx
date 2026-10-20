/* wide_bump: `++', `--' and `op=' on LONG and FLOAT lvalues, on every path
 * that used to read-modify-write one 16-bit word of them.
 *
 * A long's `++' has to carry into its high word and a float's has to add 1.0,
 * not 1 to its low mantissa bits.  Each of these compiled cleanly and ran:
 *   - `x = ++s.lw[i]'   the lvalue walker's value-position bump
 *   - `a[i].lv += 5', `a[i].lv++'   the indexed-base member nodes
 *   - `p->q->lv += 1'   the pointer-chain store
 *   - `x = s.lv++'      which also took `s''s first WORD as the base
 *                       address (apple/fgx#217's shape on the long path)
 *   - every `++'/`--' on a float, member or variable
 *
 * THE VALUES STRADDLE THE WORD.  0xFFFF + 1 is where a lost carry shows, so
 * every long arm starts there or crosses it; a 16-bit RMW leaves 0x0000 in the
 * low word and the high word unchanged.  The float arms use values exactly
 * representable in binary, and the postfix arms check the OLD value comes back
 * exactly -- a float cannot recover it as NEW - 1.0 (0.1 + 1 - 1 != 0.1).
 *
 * 14 arms x 3 = 42. */

struct sl {
	int        t;
	long       lw[2];
	long       lv;
	float      fm;
	float      fa[2];
	struct sl *nx;
};

static struct sl gobj, gvs[2], chain;
static struct sl *gp;
static float fv;

int
main()
{
	int i, r = 0;
	long x;
	float f, lf;

	gp = &gobj;
	gobj.nx = &chain;
	gobj.t = 1234;

	/* The walker's value-position bump on a long ELEMENT, across the word. */
	gobj.lw[0] = 7; gobj.lw[1] = 0xFFFFL;
	x = ++gobj.lw[1];
	if (x == 0x10000L && gobj.lw[1] == 0x10000L && gobj.lw[0] == 7) r += 3;

	/* ...and postfix `--' back across it, yielding the OLD value. */
	x = gobj.lw[1]--;
	if (x == 0x10000L && gobj.lw[1] == 0xFFFFL) r += 3;

	/* Indexed base, long member, compound. */
	i = 1;
	gvs[1].lv = 0xFFFEL; gvs[0].lv = 3;
	gvs[i].lv += 5;
	if (gvs[1].lv == 0x10003L && gvs[0].lv == 3) r += 3;

	/* Indexed base, long member, `++' as a statement. */
	gvs[i].lv = 0xFFFFL;
	gvs[i].lv++;
	if (gvs[1].lv == 0x10000L) r += 3;

	/* A pointer chain's long member, compound. */
	chain.lv = 0xFFFFL;
	gp->nx->lv += 1;
	if (chain.lv == 0x10000L) r += 3;

	/* A long member of a struct VARIABLE in value position: the base is the
	 * variable's address, not its first word (gobj.t, 1234). */
	gobj.lv = 0x1FFFFL;
	x = gobj.lv++;
	if (x == 0x1FFFFL && gobj.lv == 0x20000L && gobj.t == 1234) r += 3;

	/* A float member through the walker, as a statement. */
	gobj.fm = 2.5;
	gobj.fm++;
	if (gobj.fm == 3.5) r += 3;

	/* A float member through a pointer, prefix, value position. */
	f = --gp->fm;
	if (f == 2.5 && gobj.fm == 2.5) r += 3;

	/* A float array element, postfix, value position: OLD comes back. */
	gobj.fa[0] = 0.5; gobj.fa[1] = 8.0;
	f = gobj.fa[0]++;
	if (f == 0.5 && gobj.fa[0] == 1.5 && gobj.fa[1] == 8.0) r += 3;

	/* A float member through an indexed base (routed to the walker). */
	gvs[i].fm = 4.0;
	gvs[i].fm--;
	if (gvs[1].fm == 3.0) r += 3;

	/* A pointer chain's float member, postfix, value position. */
	chain.fm = 0.25;
	f = gp->nx->fm++;
	if (f == 0.25 && chain.fm == 1.25) r += 3;

	/* A local float, postfix in value position. */
	lf = 6.5;
	f = lf++;
	if (f == 6.5 && lf == 7.5) r += 3;

	/* A global float, as a statement and as a prefix. */
	fv = 1.0;
	fv++;
	f = --fv;
	if (fv == 1.0 && f == 1.0) r += 3;

	/* And a float compound through the indexed base. */
	gvs[i].fm += 2;
	if (gvs[1].fm == 5.0) r += 3;

	return r;				/* 42 */
}

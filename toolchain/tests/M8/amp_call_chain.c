/* M8: '&' over a chain whose BASE is a CALL -- `&f(args)->member`
 * (tcsh sh.lex `return (&enthist(-1000, &lexi, 0)->Hlex)`).
 *
 * K&R A.7.3.3 makes the '->' result an lvalue, so '&' of it is legal however
 * the base was computed.  Previously the function name was taken as `&f` (the
 * address of the function) and the leftover `(args)->m` failed to parse; the
 * '(' now distinguishes a CALL base from a function address.
 *
 * Both leaf kinds matter: a SCALAR member (address of an int inside the
 * returned struct) and a STRUCT-VALUE member.  The struct-value case is why
 * '&' must not reuse the store path's "struct-value leaf unsupported" guard:
 * '&' never derefs the leaf, it stops at the address the walker computed, and
 * tcsh's Hlex IS an embedded struct.
 *
 * Also covers a block-scope `extern T name[];` (sh.lex declares
 * `extern Char InputBuf[];` inside bgetc()).  K&R A.8.1: that DECLARES a
 * reference to the file-scope object, it does not DEFINE a local -- which is
 * why the sizeless array is legal there.  Returns 42.
 */
struct inner {
	int  lo;
	int  hi;
};

struct outer {
	int          tag;
	struct inner emb;		/* struct-VALUE member */
};

struct outer slot;
int          table[4];

struct outer *pick(t)
int t;
{
	slot.tag = t;
	return &slot;
}

int main()
{
	extern int table[];		/* block-scope extern, sizeless */
	int          *ip;
	struct inner *sp;
	int           r = 0;

	table[0] = 4;

	/* scalar leaf: address of an int inside the returned struct */
	ip = &pick(3)->tag;
	if (*ip == 3) r += 10;		/* the call really ran */
	*ip = 15;
	if (slot.tag == 15) r += 10;	/* and the address was slot's */

	/* struct-VALUE leaf: &f(...)->emb yields struct inner * */
	sp = &pick(1)->emb;
	sp->lo = 6;
	sp->hi = 12;
	if (slot.emb.lo == 6 && slot.emb.hi == 12) r += 18;

	return r + table[0];		/* 10 + 10 + 18 + 4 = 42 */
}

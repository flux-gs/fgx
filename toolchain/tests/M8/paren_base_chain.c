/* M8: GROUPING PARENS around the base of a postfix chain -- the last tcsh P0
 * blocker (sh.set's rleft/rright AVL rotate macros).  A macro that wraps its
 * parameter, `#define rleft(p) (... (p)->v_right ... )`, produces exactly this
 * whenever it is expanded; with v_right itself a macro for v_link[1] the base
 * ends up parenthesised and the chain crosses a subscript.
 *
 * K&R A.7.2: grouping parens are type- AND lvalue-transparent, so `(p)->m[i]`
 * and `p->m[i]` are the same lvalue and neither is a special case.  Three
 * spellings had to be taught, and each one failed differently:
 *
 *   1. READ  `(p)->link[1]`            -- the computed-base arrow reader
 *      decays char/int/long array members and indexes them, but a POINTER
 *      array matched neither arm and left '[' unread.
 *   2. STORE `(t)->link[2] = x` in EXPRESSION context (a comma operand or a
 *      ternary condition).  The statement form already worked; the paren arm
 *      in build_assign only knew `(base->chain) = x`, not `(base)->chain = x`.
 *   3. A paren-wrapped CHAIN as the base, `(p->link[1])->link[0]`, which
 *      needed N_ELEM_PTRELEM to carry the element's struct_id -- without it a
 *      pointer-array element was typed struct-pointer-to-NOTHING and no member
 *      could be resolved on the result.
 *
 * Both a read and a store of each spelling are exercised, because the read
 * route must NOT claim a store target: routing a store as a read consumes the
 * chain and orphans the '=' (that regression is what the `= via ternary` legs
 * below would catch).
 *
 * Returns 42.
 */
struct V {
	struct V *link[3];
	char      carr[4];
	int       iarr[4];
	int       bal;
};

struct V a, b, c;
struct V *p, *t;

int main()
{
	int r = 0;

	/* Setup via ARROW stores: the dot spelling `a.link[1] = &b` on a
	 * pointer-ARRAY member is a separate, still-open gap (the dot->index
	 * store fix is gated on the member being a POINTER, and an array OF
	 * pointers is not), and tripping it here would mask what this fixture
	 * is for. */
	p = &a;
	t = &b;
	p->link[1] = &b;
	p->carr[1] = 7;
	p->iarr[1] = 9;
	t->link[0] = &c;
	t->link[2] = &a;
	t = &c;
	t->bal     = 3;

	/* 1. reads through a parenthesised NAMED base */
	t = (p)->link[1];
	if (t == &b)             r += 5;
	if ((p)->carr[1] == 7)   r += 5;	/* char array: existing path */
	if ((p)->iarr[1] == 9)   r += 5;	/* int array:  existing path */

	/* 3. read through a parenthesised CHAIN base (needs the element's
	 *    struct_id to resolve `link` on the result) */
	t = (p->link[1])->link[0];
	if (t == &c && t->bal == 3) r += 6;

	/* 2. store with a parenthesised base, in EXPRESSION context */
	t = &b;
	if (((t)->link[2] = &c) == &c) r += 6;	/* value of the store */
	if (b.link[2] == &c)           r += 5;	/* and it reached memory */

	/* store through a parenthesised CHAIN base, as a ternary condition */
	if (((p->link[1])->link[0] = &a) ? 1 : 0) r += 5;
	if (b.link[0] == &a)                      r += 5;

	return r;			/* 5+5+5+6+6+5+5+5 = 42 */
}

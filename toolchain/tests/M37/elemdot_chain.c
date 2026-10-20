/* elemdot_chain: a member chain past an ARRAY SUBSCRIPT -- `vs[i].u.n'.
 *
 * K&R A.7.3.3 (p.163) makes the production recursive -- "A postfix expression
 * followed by a dot followed by an identifier IS a postfix expression", an
 * lvalue "if the first expression is an lvalue, and if the type of the second
 * expression is not an array type" -- so `vs[0]' being an lvalue and `u' being
 * a union makes `vs[0].u' an lvalue that may precede another dot.  fcc refused
 * the second dot on this base alone: the arrow spelling `p->u.n' compiled, and
 * `vs[0].u.n' did not.  apple/fgx#314.
 *
 * IT STORES AND READS BACK, which is the point.  The store half of this fix
 * was written once before and REVERTED as unverifiable, because every read of
 * a two-level member was itself the reject -- there was no way to see what a
 * store had done.  Fixing the reader first is what makes the writer testable,
 * so every arm here writes through the chain and then reads through it.
 *
 * THE OFFSETS ARE WHAT CAN GO WRONG, not the parse.  A chain folds to one
 * cumulative offset, so a fold that drops or double-counts a term still
 * compiles and still runs -- it just touches the wrong bytes.  Every arm below
 * therefore holds a NEIGHBOUR constant and checks it survived: a wrong offset
 * lands on the neighbour and takes its arm down too.
 *
 * 6 + 6 + 6 + 6 + 6 + 6 + 6 = 42. */

struct inner { int n; char s[4]; };
struct slot  { int t; struct inner u; };
struct deep  { int pad; struct slot d; };

union  uv    { int num; char *str; };
struct tag   { int type; union uv u; };

static struct slot  vs[3];
static struct deep  dp[2];
static struct tag   valstack[3];
static struct inner src;

int
main()
{
	int i, r = 0;

	/* A constant-index store, read back through the same chain, with the
	 * sibling member `t' holding a neighbour value.  A fold that loses the
	 * outer member's offset writes over `t'. */
	vs[0].t = 11;
	vs[0].u.n = 22;
	if (vs[0].u.n == 22 && vs[0].t == 11) r += 6;

	/* A RUNTIME index, with element 1 as the neighbour.  A fold that drops
	 * the element stride writes into vs[0]. */
	i = 1;
	vs[1].t = 33;
	vs[i].u.n = 44;
	if (vs[i].u.n == 44 && vs[1].t == 33 && vs[0].u.n == 22) r += 6;

	/* Compound assignment and postfix increment through the chain. */
	vs[i].u.n += 2;
	vs[i].u.n++;
	if (vs[i].u.n == 47 && vs[1].t == 33) r += 6;

	/* An ARRAY member at the end of the chain: `vs[i].u.s[j]'.  Its first
	 * byte sits immediately after `n', so a fold that under-counts by two
	 * writes over `n' instead. */
	vs[1].u.s[0] = 'A';
	vs[1].u.s[2] = 'C';
	if (vs[1].u.s[0] == 'A' && vs[1].u.s[2] == 'C' && vs[1].u.n == 47)
		r += 6;

	/* THREE levels, `dp[i].d.u.n', which is where a cumulative fold differs
	 * from a single member's offset for the first time.  `pad' and `d.t'
	 * are both neighbours on the way in. */
	dp[1].pad = 55;
	dp[1].d.t = 66;
	dp[1].d.u.n = 77;
	if (dp[1].d.u.n == 77 && dp[1].d.t == 66 && dp[1].pad == 55) r += 6;

	/* A UNION member, which is test(1)'s own shape (`valstack[0].u.num').
	 * A union's members all sit at offset 0 within it, so this checks the
	 * ENCLOSING offset is still added. */
	valstack[0].type = 88;
	valstack[0].u.num = 99;
	valstack[1].u.num = 100;
	if (valstack[0].u.num == 99 && valstack[0].type == 88 &&
	    valstack[1].u.num == 100) r += 6;

	/* A whole-struct store THROUGH the element, which takes the same base
	 * with the member offset folded in.  It must land on `u' and leave `t'
	 * alone. */
	src.n = 123;
	vs[2].t = 121;
	vs[2].u = src;
	if (vs[2].u.n == 123 && vs[2].t == 121) r += 6;

	return r;				/* 42 */
}

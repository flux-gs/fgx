/* ++/-- on a chain whose base is COMPUTED -- a call result or an index
 * (apple/fgx#153).  K&R A.7.3 lists `postfix-expression ++' in the same
 * left-to-right production as `->', `[]' and the call itself, and A.7.4.1
 * takes prefix ++/-- on ANY modifiable lvalue; fcc rejected every one of
 * these with "expected ';'".  Both spellings, both positions, value and
 * statement context.
 *
 * The three things a parse fix does not prove, so they are checked here:
 * postfix yields the OLD value and prefix the NEW one, the bump actually
 * lands in memory, and the base is evaluated ONCE (calls counts it -- a
 * desugaring to `E = E + 1' would call twice and is the obvious wrong way
 * to build this).  -> 42. */
struct in { int x; int y; };
struct nn { int a; int b; struct in *ip; int m; };
typedef struct nn *NP;

struct nn	root;
struct in	sub[3];
int		vec[4];
int		calls;

NP
lookup(n)
	int n;
{
	calls++;
	return &root;
}

int *
ivec()
{
	calls++;
	return vec;
}

int main(void)
{
	int t;

	root.m = 10;
	calls  = 0;

	t = lookup(1)->m++;                     /* postfix: OLD */
	if (t != 10)            return 1;
	if (root.m != 11)       return 2;

	t = ++lookup(1)->m;                     /* prefix: NEW */
	if (t != 12)            return 3;
	if (root.m != 12)       return 4;

	lookup(1)->m--;                         /* statement position */
	if (root.m != 11)       return 5;
	++lookup(1)->m;
	if (root.m != 12)       return 6;

	if (calls != 4)         return 7;       /* ONE call per statement */

	/* index on a call result */
	vec[2] = 5;
	calls  = 0;

	t = ivec()[2]++;
	if (t != 5)             return 8;
	if (vec[2] != 6)        return 9;

	t = ++ivec()[2];
	if (t != 7)             return 10;
	if (vec[2] != 7)        return 11;

	ivec()[2]--;
	if (vec[2] != 6)        return 12;

	if (calls != 3)         return 13;

	/* prefix on a NAMED base with an index -- the postfix twin always
	 * worked, the prefix one did not */
	vec[1] = 20;
	t = ++vec[1];
	if (t != 21)            return 14;
	if (vec[1] != 21)       return 15;
	++vec[1];
	if (vec[1] != 22)       return 16;

	/* a POINTER leaf: the bump is by stride, not by one */
	sub[0].x = 100;
	sub[1].x = 200;
	root.ip  = &sub[0];
	if (lookup(1)->ip++->x != 100)  return 17;
	if (root.ip->x != 200)          return 18;

	return 42;
}

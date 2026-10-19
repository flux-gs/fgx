/* Parenthesized struct-lvalue member access: `(s).field`.  The bare `s.field`
 * path handled this, but a redundant paren — as BSD macros emit, e.g.
 * ISDIR(st) == ((st).st_mode & S_IFMT) == S_IFDIR — routed `s` through the
 * value-chain, which stopped short of the '.'.  build_postfix_value_chain now
 * re-enters build_dot_access on a struct value still backed by a local/global.
 * Regression for the mv(1) port's ISDIR/ISREG macros.  -> 42. */
struct S { int a; int mode; };
struct S g;
#define FIELD(x) ((x).mode)
#define ISBIT(x) (((x).mode & 0xF0) == 0x40)

int main(void)
{
	struct S s;
	int r;
	s.a = 1; s.mode = 0x40;
	g.a = 2; g.mode = 0x02;
	if ((s).a != 1) return 1;          /* (local).field read */
	if (FIELD(s) != 0x40) return 2;    /* macro paren member */
	if (!ISBIT(s)) return 3;           /* masked compare, ISDIR-style */
	if ((g).mode != 0x02) return 4;    /* (global).field read */
	r = 42;
	return r;
}

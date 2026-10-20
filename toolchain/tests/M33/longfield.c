/* longfield.c — B-4 completion (2026-07-06): long ARRAY struct members
 * (load/store via '.' and '->', with bank-honoring [_fcc_ptr] element
 * addressing and int-RHS promotion) + long scalar-field brace-init.
 * Both died fail-closed before: "expected '='" at the member-index use
 * site, and "struct-array init: field must be int/char/char-ptr/fn-ptr
 * (M22)" for the initializer.  Exit 42 = pass; 1..8 = failing property.
 */
struct s { long a[3]; int tag; };
struct t { long l; int i; };

struct s g;
struct t gt = { 70000, 5 };                    /* long-field brace-init */
struct t arr[2] = { {1, 2}, {100000, 4} };     /* incl. a >16-bit value */

int main()
{
	struct s *p;
	long v;

	p = &g;
	g.a[0] = 70000;                    /* '.' store, 32-bit constant */
	g.a[1] = 5;                        /* '.' store, int RHS promoted */
	p->a[2] = 123456;                  /* '->' store */
	if (g.a[2] != 123456) return 1;    /* '.' load sees '->' store */
	v = p->a[0];                       /* '->' load */
	if (v != 70000) return 2;
	if (p->a[1] != 5) return 3;        /* promoted RHS high word clean */
	g.tag = 7;
	if (g.tag != 7) return 4;          /* neighbour field intact */
	if (g.a[2] != 123456) return 5;    /* ... and didn't clobber a[2] */
	if (gt.l != 70000 || gt.i != 5) return 6;
	if (arr[1].l != 100000 || arr[1].i != 4) return 7;
	if (arr[0].l != 1 || arr[0].i != 2) return 8;
	return 42;
}

/* floatfield.c — B-6 completion (2026-07-09): float ARRAY struct members
 * (load/store via '.' and '->', int-RHS itof promotion) — the float half
 * of M33/longfield's B-4 fix.  Died fail-closed before: "expected '='" at
 * the member-index use site.  Exit 42 = pass; 1..6 = failing property.
 */
struct s { float f[3]; int tag; };

struct s g;

int main()
{
	struct s *p;
	float v;

	p = &g;
	g.f[0] = 1.5;                      /* '.' store, float literal */
	g.f[1] = 2;                        /* '.' store, int RHS -> itof */
	p->f[2] = 0.25;                    /* '->' store */
	if (g.f[2] != 0.25) return 1;      /* '.' load sees '->' store */
	v = p->f[0];                       /* '->' load */
	if (v != 1.5) return 2;
	if (p->f[1] != 2.0) return 3;      /* promoted RHS converted, not raw */
	g.tag = 7;
	if (g.tag != 7) return 4;          /* neighbour field intact */
	if (g.f[2] != 0.25) return 5;
	v = g.f[0] + p->f[1];              /* float ARITHMETIC on elements */
	if (v != 3.5) return 6;
	return 42;
}

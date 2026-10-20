/* Array DIMENSION as an integer constant EXPRESSION (char buf[N+1]), not just
 * a bare literal -- across global, static-local, and struct-field decls.  fcc
 * once accepted this only for plain locals (G33); the global/static/field
 * parsers wanted a single literal ("expected ']'" on `buf[LBSIZE+1]`, which
 * the grep port hit).  Index N is valid iff the dim evaluated to N+1.  -> 42. */
#define N 10
char gbuf[N + 1];                 /* global: 11 elements */
struct S { int f[N + 1]; };       /* field:  11 elements */

int main(void)
{
	static char sb[N + 1];    /* static-local: 11 elements */
	struct S s;

	gbuf[N] = 7;
	sb[N]   = 9;
	s.f[N]  = 5;
	if (gbuf[N] != 7) return 1;
	if (sb[N]   != 9) return 2;
	if (s.f[N]  != 5) return 3;
	return 42;
}

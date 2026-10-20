/* Gap-3b completion: deref-call through a fn-ptr VALUE reached by a plain
 * load (not an indexed table) — a global fn-ptr `(*gfp)(args)`, a fn-ptr
 * struct field via a LOCAL base `(*lp->fn)(args)` (elvis vi.c:462's
 * `(*keyptr->func)(...)` idiom), and via a GLOBAL base `(*ggp->fn)(args)`.
 * The load helpers now carry g_expr_fn_sig alongside the fn-ptr value, so the
 * trailing `(args)` is recognized as a call instead of left dangling
 * ("expected ';'").  -> 42. */
long add3(char *t, long a, long b) { return a + b + (long)t[0]; }

struct disp { long (*fn)(char *, long, long); };
struct disp  gdisp;
struct disp *ggp;
long (*gfp)(char *, long, long);
char one = 1;

int main(void)
{
	struct disp *lp;
	long         r;

	gfp      = add3;
	gdisp.fn = add3;
	ggp      = &gdisp;
	lp       = &gdisp;

	r  = (*gfp)(&one, 5L, 6L);       /* 5+6+1  = 12, global fn-ptr var  */
	r += (*lp->fn)(&one, 7L, 8L);    /* 7+8+1  = 16, fn-ptr field, local base  */
	r += (*ggp->fn)(&one, 3L, 10L);  /* 3+10+1 = 14, fn-ptr field, global base */
	return (int)r;                   /* 42 */
}

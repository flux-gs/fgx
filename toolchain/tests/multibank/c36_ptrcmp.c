/* c36_ptrcmp.c — pointer comparison as a full (offset+bank) value.
 *
 * P3-2 model edge: equality must hold for the SAME object reached by
 * different routes (direct, via a data-bank global, via a struct field,
 * via a function return), must fail across different objects/banks, and
 * a stored NULL must stamp bank 0 even when the pointer carrier was just
 * poisoned with a heap bank (the assign-path sibling of c35's return
 * path).  Relational <,+1 compares exercise the offset half. */
extern char *malloc(unsigned long);   /* WIDE (M-4): a K&R empty-paren decl pushes 16-bit args where malloc reads a 32-bit size */

char *c36_ga;                    /* data-bank home for a heap ptr */
struct c36s { char *f; int pad; };
struct c36s c36_st;
char c36_arr[8];

static char *
c36_ident(p)
	char *p;
{
	return p;
}

int
c36_check(void)
{
	char *h = malloc(4);
	char *d = c36_arr;
	if (!h) return 0;
	c36_ga  = h;
	c36_st.f = h;
	if (c36_ga != h) return 0;             /* reload from data bank */
	if (c36_st.f != c36_ident(h)) return 0; /* via field vs via fn return */
	if (h == d) return 0;                  /* different objects differ */
	if (h == 0 || d == 0) return 0;        /* valid ptr != NULL */
	if (d != c36_arr) return 0;
	if (d == c36_arr + 1) return 0;        /* offset half matters */
	if (!(d < c36_arr + 3)) return 0;      /* relational, same array */
	*h = 42;                               /* poison carrier w/ heap bank */
	c36_st.f = 0;                          /* stored NULL must stamp bank 0 */
	if (c36_st.f != 0) return 0;
	return *h == 42;
}

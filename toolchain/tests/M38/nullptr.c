/* THE NULL POINTER CONSTANT, IN THE THREE PLACES fcc DID NOT TAKE IT.
 *
 * K&R 2nd ed A.7.16 (p.168) decides the first: "If one is a pointer and the
 * other the constant 0, the 0 is converted to the pointer type, and the result
 * has that type."  fcc took the ELSE arm's type unconditionally, so
 * `p ? q : 0' was an INT -- and on this machine a pointer is four bytes and an
 * int is two, so the then arm's far pointer was truncated to its offset, its
 * bank dropped, and a call taking the result pushed two bytes where the callee
 * reads four.  2.11BSD's mount(8) writes exactly that -- `catopt(mntopts ?
 * strdup(mntopts) : 0, options)' -- and it hung the machine with no output.
 *
 * A.6.6 (p.160) decides the other two: "an integral constant 0, optionally
 * cast" is a null pointer.  fcc's field_init_is_null already read that
 * sentence for STRUCT FIELDS; a `char *[]' item and a static-local initializer
 * are the same question and took only the bare `0'.  They became reachable
 * when <stdio.h>'s NULL grew a cast: it was a bare 0, which is 2.11BSD's own
 * spelling and correct on a PDP-11 where int and pointer are both two bytes,
 * and is `((char *)0)' here because they are not -- otherwise every K&R port
 * passing NULL to an unprototyped function pushes two bytes for four
 * (apple/fgx#327's family).
 *
 * WHAT THIS ASSERTS AND WHAT IT CANNOT.  A golden diff proves the ternary
 * emits a FOUR-BYTE push -- `PEI _fcc_fpr0+2 / PEI _fcc_fpr0' rather than a
 * single `PHA' -- and the runtime arm proves the pointer still points at its
 * string.  Before the fix this file did not compile at all past the static
 * local, so every arm is also a compile assertion.
 */
#include <stdio.h>

char *ident(s)
	char *s;
{
	return (s);
}

/* char *[] item: the cast-null form. */
static char *tab[] = { "aa", "bb", NULL };

/* static local: the same constant again. */
char *
pick(want)
	int want;
{
	static char *cached = NULL;

	if (cached == NULL)
		cached = "zz";
	return (want ? ident(cached) : NULL);
}

main()
{
	char *p;
	int   n;

	/* The ternary whose arms are a POINTER and the constant 0.  Passing it
	 * straight into a function is the shape that failed: the argument push
	 * is where the width shows. */
	p = ident(tab[0] ? ident(tab[1]) : NULL);
	n = (p[0] == 'b') + (p[1] == 'b');          /* 2 if the bank survived */

	p = pick(1);
	n += (p[0] == 'z');                          /* 3 */
	n += (pick(0) == NULL);                      /* 4 */
	n += (tab[2] == NULL);                       /* 5 */
	return (n);
}

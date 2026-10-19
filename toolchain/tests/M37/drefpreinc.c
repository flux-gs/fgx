/* ++(*p) / --(*p) in EXPRESSION context — prefix inc/dec through a pointer
 * deref, desugared onto the deref-store path (`*p = *p +/- 1`).  Was: die
 * "expected identifier after '++' / '--'".  compress's getopt idiom
 * `while (*++(*argv))` and `ARGVAL()` use exactly this expression form.
 * *pp points at rp (a char*); ++(*pp) advances rp then the outer * derefs.
 * Exit 42. */
char buf[] = { 'A', 'B', 'C', 0 };
char *rp;
char **pp;

int main(void)
{
	char x;
	rp = buf;
	pp = &rp;
	x = *++(*pp);              /* advance rp to buf[1], deref -> 'B' */
	if (x != 'B') return 1;
	if (rp != buf + 1) return 2;
	x = *--(*pp);             /* back to buf[0], deref -> 'A' */
	if (x != 'A') return 3;
	if (rp != buf) return 4;
	return x - 'A' + 42;      /* 42 */
}

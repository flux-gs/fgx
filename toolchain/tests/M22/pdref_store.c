/* Deref-store through a REDUNDANTLY-PARENTHESIZED pointer identifier:
 * `*(s)++ = rhs` and `*(s) = rhs` — elvis regexp.c's ADD_META macro
 * `(*(s)++ = META, *(s)++ = BASE_META(m))` (a parenthesized comma expression,
 * so each store is parsed in EXPRESSION context).  `*(s)++` is `*((s)++)`: the
 * `++` is a POST-op outside the parens.  The parens around the bare identifier
 * are stripped so it flows through the working `*s++ = rhs` deref-store path;
 * a non-`(IDENT)` inner rewinds cleanly.  -> 42. */
#define ADD2(s,a,b)  (*(s)++ = (a), *(s)++ = (b))

char buf[8];

int main(void)
{
	char *s;

	s = buf;
	ADD2(s, 10, 20);          /* buf[0]=10, buf[1]=20; s -> buf[2] */
	*(s) = 12;                /* buf[2]=12 (plain parenthesized deref assign) */

	if (buf[0] != 10)   return 1;
	if (buf[1] != 20)   return 2;
	if (buf[2] != 12)   return 3;
	if (s != buf + 2)   return 4;   /* s advanced exactly twice */

	return buf[0] + buf[1] + buf[2];  /* 10 + 20 + 12 = 42 */
}

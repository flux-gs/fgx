/* sizeof(*expr) — parenthesized deref in sizeof.  Was: only `sizeof IDENT`,
 * `sizeof(type)`, and unparenthesized `sizeof *ident` were accepted;
 * `sizeof(*p)` die'd ("sizeof(expr) not supported").  compress needs it for
 * `malloc(argc * sizeof(*argv))`.  sizeof(*pp)=4 (char*), sizeof(*ip)=2 (int).
 * Exit 42. */
char  c;
char *cp = &c;
char **pp = &cp;
int   iv;
int  *ip = &iv;

int main(void)
{
	return (int)sizeof(*pp) * 10 + (int)sizeof(*ip);   /* 4*10 + 2 = 42 */
}

/* Three '->'/addr-of fcc gaps surfaced by the 2.11BSD sed port:
 *   &p[i]      where p is a struct pointer  (G35 ext: struct stride)
 *   &p->field  bare addr-of an '->'member, no index   (G30 bare-field)
 *   gpp++      ++/-- of a pointer-to-pointer GLOBAL    (G36 -> ISPTR)
 * (sed: `&labtab[LABSIZE]`, `cmpend[depth++] = &rep->lb1`, `eargv--`.)
 * Matches clang: ret 13. */
struct lab { char asc[9]; int n; };
struct lab tbl[4];
struct lab *p = tbl;
char *strs[3];
char **gpp = strs;
int main(){
	struct lab *e;
	int *np;
	e = &p[2];          /* &structptr[i] -> &tbl[2] */
	e->n = 9;
	np = &p->n;         /* bare &structptr->field -> &tbl[0].n */
	*np = 4;
	gpp++;              /* global char** increment (stride 4) */
	*gpp = 0;
	return tbl[2].n + tbl[0].n;   /* 9 + 4 = 13 */
}

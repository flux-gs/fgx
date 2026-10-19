/* Five more lvalue/init fcc gaps from the 2.11BSD sed port (which now
 * compiles clean with these):
 *   &(p->asc[i])   paren-transparent addr-of + indexed in-struct ARRAY member
 *   *++bp = v      prefix-increment deref-store (expr context)
 *   *bp++ |= v     compound-assign through a post-incremented deref (stmt)
 *   (bp[i] = v)    expr-context assign through a POINTER index (not an array)
 *   &ptrarr[i]     addr-of an element of an array-of-pointers
 *   char r[]={"s"} brace-wrapped string literal char-array init
 * (sed: `&(lab->asc[8])`, `*++p=*q++`, `*p++|=0200`, `ep[c]=*tsp++`,
 *  `&abuf[ABUFSIZE]`, `char rub[]={"\177"}`.)  Matches clang: ret 27. */
char buf[16];
char rub[] = {"\03"};
char *ptrarr[4];
struct lab { char asc[9]; int n; };
struct lab L;
int main(){
	struct lab *lp;
	char *q, *bp;
	char **pp;
	int r;
	lp = &L;
	q = &(lp->asc[3]);
	*q = 7;
	bp = buf;
	*++bp = 4;
	*bp++ |= 0x02;
	r = (bp[0] = 5);
	pp = &ptrarr[2];
	*pp = buf;
	return L.asc[3] + buf[1] + buf[2] + r + rub[0] + (pp == &ptrarr[2] ? 1 : 0);
}

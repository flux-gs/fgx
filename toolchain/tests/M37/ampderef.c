/* H1-touch regression: `&(*p)[i]` — address of an element of the pointee,
 * semantically `*p + i` (2.11BSD touch's `argp = &(*argv)[1]`).  Was a
 * parse reject ("expected identifier after '&'").  Covers char** (stride
 * 1) and struct** (struct stride through the deref).  Exit 42. */
struct s6 { int a; int b; int c; };

char row[] = "hello";
char *rp = row;
char **pp = &rp;

struct s6 arr[3];
struct s6 *sp = arr;
struct s6 **spp = &sp;

int main(void)
{
	char *cp;
	struct s6 *ep;

	cp = &(*pp)[1];                 /* row + 1 -> "ello" */
	if (*cp != 'e') return 1;
	cp = &(*pp)[4];
	if (*cp != 'o') return 2;
	arr[2].b = 30;
	ep = &(*spp)[2];                /* arr + 2 (stride 6) */
	if (ep->b != 30) return 3;
	return 12 + *cp - 'o' + 30;     /* 12 + 0 + 30 = 42 */
}

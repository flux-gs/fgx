/* Deref of a postfix access on a LOCAL/param base: `*av[i]` (main.c's flag scan
 * `*argv[i] == '-'`, argv a char** param) and `*lb.p` (local struct field).  The
 * `*IDENT` fast path now falls to the general postfix parser when a '[' or '.'
 * follows the local IDENT, instead of dereferencing the bare base and dropping
 * the postfix ("expected ';'").  -> 42. */
char *g0 = "Ax";
char *g1 = "Bx";
char *tab[2];

struct box { int tag; char *p; };

int probe(char **av)
{
	struct box lb;

	if (*av[0] != 'A') return 1;   /* *av[0] = g0[0] = 'A' (param subscript) */
	if (*av[1] != 'B') return 2;   /* *av[1] = g1[0] = 'B' */
	lb.p = av[1];
	if (*lb.p != 'B') return 3;    /* *lb.p (local struct '.' base)          */
	return 42;
}

int main(void)
{
	tab[0] = g0;
	tab[1] = g1;
	return probe(tab);
}

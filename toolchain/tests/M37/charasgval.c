/* The value of an assignment to a char is the byte stored (K&R A.7.17: "the
 * value is the value stored in the left operand after the assignment has
 * taken place"), for each kind of store: a local, a global, through a
 * pointer, an array element, a member through a pointer, a struct member,
 * a compound assignment, and a chain.  Each stores 0x1C1 and reads back
 * 0xC1.  Returns 42 when every value is the byte. */
struct s { int i; char c; };

char g;
char ga[4];
struct s gs;

int
main()
{
	char l, *p;
	struct s *sp;
	int v, r, n;

	v = 0x1C1;
	p = ga;
	sp = &gs;
	r = 0;
	n = 0;
	if ((l = v) == 0xC1) n++;
	if ((g = v) == 0xC1) n++;
	if ((*p = v) == 0xC1) n++;
	if ((ga[2] = v) == 0xC1) n++;
	if ((sp->c = v) == 0xC1) n++;
	if ((gs.c = v) == 0xC1) n++;
	l = 0x80;
	if ((l += 0x141) == 0xC1) n++;
	if ((v = (g = 0x2C1)) == 0xC1) n++;
	if (n == 8) r += 40;
	g = v;			/* a discarded value needs no mask */
	if (g == 0xC1 && ga[0] == 0xC1 && ga[2] == 0xC1) r += 2;
	return r;
}

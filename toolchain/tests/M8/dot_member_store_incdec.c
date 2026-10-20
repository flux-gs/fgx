/* M8: two statement-context gaps on a DOT member of a struct VARIABLE.
 * Both come from tcsh sh.lex, where `fbuf` and `fseekp` are macros for
 * B.Bfbuf (a Char **) and B.Bfseekp (an off_t).
 *
 * 1. STORE through a subscripted POINTER member: `B.pp[0][i] = x`.
 *    build_dot_access consumes '[' only for ARRAY leaves, so a POINTER leaf
 *    fell through with '[' unread -- the store twin of the read gap fixed in
 *    52e32a4a.  Routing it needs a TYPE gate, not just a token shape: the
 *    ARRAY-member twin `B.arr[i] = x` has a working per-shape handler and
 *    routing that one instead steals 11 goldens.  Hence both members here --
 *    `arr` must keep its old codegen while `pp` gets the walker.
 *
 * 2. POSTFIX ++/-- on a dot member: `B.n++;` and `B.big++;`.  The statement
 *    dot path had '=' and 'op=' arms but no incdec arm at all, while the
 *    arrow twin `p->f++` always had one.  The LONG leg matters separately:
 *    a 16-bit increment would lose the carry into the high word, so `big`
 *    starts at 0xFFFF and must roll over to 0x10000.
 *
 * Returns 42.
 */
struct B {
	char **pp;			/* POINTER member -> walker */
	int    arr[3];			/* ARRAY member  -> keeps its handler */
	int    n;
	long   big;
};

struct B B;
char  row[4];
char *rows[2];

int main()
{
	int i, r = 0;

	rows[0] = row;
	B.pp = rows;
	for (i = 0; i < 4; i++)
		B.pp[0][i] = (char) (i + 1);	/* subscripted pointer member */
	if (row[0] == 1 && row[3] == 4) r += 12;

	B.arr[1] = 5;			/* array member: unchanged path */
	if (B.arr[1] == 5) r += 8;

	B.n = 9;
	B.n++;				/* dot postfix on an int leaf */
	B.n++;
	if (B.n == 11) r += 8;

	B.big = 0xFFFF;			/* carry must reach the high word */
	B.big++;
	if (B.big == 0x10000L) r += 14;

	return r;			/* 12 + 8 + 8 + 14 = 42 */
}

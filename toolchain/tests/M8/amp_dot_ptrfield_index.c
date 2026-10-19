/* M8: '&' of a SUBSCRIPTED POINTER member reached through a dot --
 * `&B.pp[i]` (tcsh sh.lex `blkcpy(B.Bfbuf, &B.Bfbuf[sb])`, Bfbuf a Char **).
 *
 * The '&' parser's dot arm indexes only ARRAY fields, so a POINTER leaf fell
 * through to the bare-member arm with '[' unread ("expected ')'").  K&R
 * A.7.4.2 applies '&' to any lvalue and A.7.3 makes ./[] one postfix
 * production, so the pointer leaf is not a special case -- it routes through
 * the same uniform walker the read and store twins use.
 *
 * The ARRAY-field member `ai` is here deliberately: it must KEEP its existing
 * handler (N_ADDR_DOT_ARRFIELD).  Routing it too would be silent case theft,
 * which is why the fix is gated on the field actually being a pointer.
 *
 * Returns 42.
 */
struct B {
	char **pp;			/* POINTER member -> walker            */
	int    ai[4];			/* ARRAY member   -> existing handler  */
};

struct B B;
char *rows[3];
char  r0[2], r1[2];

int main()
{
	char **q;
	int   *ip;
	int    r = 0;

	r0[0] = 5;
	r1[0] = 9;
	rows[0] = r0;
	rows[1] = r1;
	B.pp = rows;
	B.ai[0] = 1;
	B.ai[1] = 2;
	B.ai[2] = 3;

	q = &B.pp[1];			/* element 1 of the pointer member */
	if (*q == r1)      r += 10;	/* right element (stride sizeof(char*)) */
	if ((*q)[0] == 9)  r += 10;	/* and the far pointer still derefs */

	ip = &B.ai[2];			/* array-field twin: unchanged path */
	if (*ip == 3)      r += 11;
	*ip = 14;
	if (B.ai[2] == 14) r += 11;

	return r;			/* 10 + 10 + 11 + 11 = 42 */
}

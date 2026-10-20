/* Deref-store through a GLOBAL pointer used as a value-producing EXPRESSION
 * (elvis's addch macro: `(*stdscr++ = ch) == '\n'`, stdscr a global pointer).
 * fcc's parse_assign deref-store fast-path handled only LOCAL pointers; the
 * global path fell through to the rvalue parser ("expected ')'").  Verifies the
 * store byte, the yielded value, and the post-increment — char and int.  -> 42. */
char  buf[8];
char *gp;
int   ibuf[4];
int  *ip;

int main(void)
{
	int v;

	gp = buf;
	v = (*gp++ = 65);                 /* store 'A', yield 65, advance gp */
	if (v != 65)          return 1;
	if (buf[0] != 65)     return 2;
	if (gp != buf + 1)    return 3;
	if ((*gp++ = 66) != 66) return 4; /* store 'B' at buf[1] */
	if (buf[1] != 66)     return 5;

	ip = ibuf;
	if ((*ip++ = 1000) != 1000) return 6;   /* int pointee, 2-byte store */
	if (ibuf[0] != 1000)  return 7;
	if (ip != ibuf + 1)   return 8;
	return 42;
}

/* A scalar global initialized with a cast-of-constant: `char *CQ = (char *)0;`
 * ... `(char *)4` — curses.c's cursor-shape sentinels — and `(int)N`.  The
 * constant-initializer evaluator now recognizes a cast in its paren branch and
 * returns the casted constant (a pointer keeps the integer's bit pattern; bank
 * is 0).  -> 42. */
char *cq = (char *)0;
char *cx = (char *)1;
char *cv = (char *)4;
int   gi = (int)7;

int main(void)
{
	if (cq != (char *)0) return 1;
	if (cx != (char *)1) return 2;
	if (cv != (char *)4) return 3;
	if (gi != 7)         return 4;
	return 42;
}

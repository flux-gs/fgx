/* Prefix '++'/'--' on a REDUNDANTLY-PARENTHESIZED operand identifier:
 * `*++(p)`, `++(a)` (rvalue) and `++(gi);` (statement) — elvis regexp.c's
 * GET_META `(*(s) == META ? INT_META(*++(s)) : *s)`.  Leading '('s are consumed
 * and the matching ')'(s) closed at each return, mirroring the '&(lvalue)'
 * handler; covers a pointer operand, an int-local operand, and a global.
 * -> 42. */
char buf[4];
int gi;

int main(void)
{
	char *p;
	int a, x, y;

	buf[0] = 10; buf[1] = 20; buf[2] = 30;
	a = 40;
	p = buf;

	x = *++(p);      /* p -> buf[1]; x = 20 (pointer operand, rvalue) */
	y = ++(a);       /* a = 41; y = 41 (int local operand, rvalue)    */
	gi = 1; ++(gi);  /* gi = 2 (global operand, statement)            */

	if (p != buf + 1) return 1;
	if (a != 41)      return 2;
	if (gi != 2)      return 3;

	return (y - x) * gi;   /* (41 - 20) * 2 = 42 */
}

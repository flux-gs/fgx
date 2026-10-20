/* Prefix '++'/'--' on a deref LVALUE at statement level: `++*sp` / `--*sp`
 * where sp is char** — bumps the char* that sp points to (NOT sp), matching
 * elvis regexp.c gettoken's `++*sptr`.  At statement level the result is
 * discarded, so this shares G41's `(*ptr)++` deref-RMW helper; the char*
 * pointee has stride 1 and only the offset word is bumped.  -> 42. */
char buf[8];

int adv(char **sp)  { ++*sp; return **sp; }   /* prefix ++ of a char* pointee */
int back(char **sp) { --*sp; return **sp; }   /* prefix -- of a char* pointee */

int main(void)
{
	char *p;
	int a, b, c;

	buf[0] = 5; buf[1] = 10; buf[2] = 15; buf[3] = 20;
	p = buf;

	a = adv(&p);    /* p -> buf[1] = 10 */
	b = adv(&p);    /* p -> buf[2] = 15 */
	c = back(&p);   /* p -> buf[1] = 10 */
	if (*p != 10) return 1;

	return a + b + c + 7;   /* 10 + 15 + 10 + 7 = 42 */
}

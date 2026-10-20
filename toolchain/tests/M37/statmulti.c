/* static <type> a = .., b, c = ..;  — multiple comma-separated declarators
 * sharing one base type as static locals.  Was: parse_static_local handled
 * a single declarator then die'd "expected ';'" at the ','.  compress
 * getcode: `static int offset = 0, size = 0;`.  Exit 42. */
int main(void)
{
	static int  a = 40, b, c = 2;
	static char buf[4], *p;
	static long n = 100;

	b = 0;
	p = buf;
	*p = 7;
	if (n != 100) return 1;
	if (*p != 7) return 2;
	return a + b + c;    /* 40 + 0 + 2 = 42 */
}

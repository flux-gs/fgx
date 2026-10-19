/* c10_heap.c — construct 10: a malloc'd pointer (heap bank), written and read
 * back through a SECOND, independently-derived pointer (via a function return),
 * so a consistent-wrong-bank deref isn't invisible. */
extern char *malloc(unsigned long);   /* WIDE (M-4): a K&R empty-paren decl pushes 16-bit args where malloc reads a 32-bit size */

static unsigned char *c10_id(unsigned char *p) { return p; }   /* returns p via _fcc_ptr+2 */

int c10_check(void)
{
	unsigned char *h = (unsigned char *)malloc(4);
	if (!h) return 0;
	h[0] = 0xA1; h[1] = 0xA2; h[2] = 0xA3; h[3] = 0xA4;
	{
		unsigned char *h2 = c10_id(h);   /* 2nd, independently-derived ptr */
		return h2[0] == 0xA1 && h2[3] == 0xA4 && h[1] == 0xA2;
	}
}

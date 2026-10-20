/* c41_realloc.c — construct 41: realloc'd heap pointer provenance (train 2
 * phase 0b).  Grow a malloc'd block well past its original chunk so realloc
 * takes the move path; the RETURNED pointer (bank composed from the syscall
 * return, transiting _fcc_ptr+2) must reach the moved block — old contents
 * intact, new tail writable — verified through a SECOND independently-
 * derived pointer (the c10 rule: a consistent-wrong-bank deref must not be
 * invisible).  Direct regression guard for the MM-native malloc train,
 * which rewrites malloc/realloc's block placement + bank composition. */
extern char *malloc(unsigned long);   /* WIDE (M-4): a K&R empty-paren decl pushes 16-bit args where malloc reads a 32-bit size */
extern char *realloc(char *, unsigned long);   /* WIDE (M-4) */

static unsigned char *c41_id(unsigned char *p) { return p; }

int c41_check(void)
{
	unsigned char *h = (unsigned char *)malloc(8);
	unsigned char *big;
	unsigned char *big2;
	if (!h) return 0;
	h[0] = 0xB1; h[7] = 0xB8;
	big = (unsigned char *)realloc(h, 4096);   /* grow -> move path */
	if (!big) return 0;
	big[4095] = 0xC7;                          /* write past the OLD size */
	big2 = c41_id(big);
	return big2[0] == 0xB1 && big2[7] == 0xB8 && big2[4095] == 0xC7;
}

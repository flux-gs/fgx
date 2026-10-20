/* c18_setjmp.c — construct 18: setjmp here, longjmp from a callee in ANOTHER
 * bank; the restored PB/DBR must be correct so the post-return global read works.
 * jmp_buf is a file-scope global (fcc setjmp/longjmp requires static storage);
 * c18_jump (a different code bank) longjmps back to this setjmp point. */
#include <setjmp.h>
extern void c18_jump(void);         /* separate TU, other bank; does longjmp(c18_env, 7) */
jmp_buf c18_env;
unsigned char c18_g[4] = { 0x18, 0x28, 0x38, 0x48 };

int c18_check(void)
{
	int r = setjmp(c18_env);
	if (r == 0) c18_jump();             /* cross-bank call; c18_jump longjmps back here */
	return r == 7 && c18_g[0] == 0x18 && c18_g[3] == 0x48;   /* DBR intact after longjmp */
}

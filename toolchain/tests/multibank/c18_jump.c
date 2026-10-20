/* c18_jump.c — extern callee pinned in a different code bank than c18_setjmp;
 * longjmps back across the bank boundary.  The restored PB/DBR must be correct.
 *
 * References the GLOBAL c18_env directly (NOT a jmp_buf parameter): FGX's jmp_buf
 * is a struct typedef, so `void f(jmp_buf e)` would pass it BY VALUE (a soft-stack
 * local copy) and longjmp would then address that copy DBR-relative -> wrong bank
 * -> hang.  A jmp_buf must have static storage; longjmp on the global is correct. */
#include <setjmp.h>
extern jmp_buf c18_env;

void c18_jump(void) { longjmp(c18_env, 7); }

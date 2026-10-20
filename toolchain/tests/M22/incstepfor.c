/* M22: regression for the fcc for-loop step-replay use-after-free when a file is
 * #included (parse_stmt.c -- the G39b step-buffer free must be gated on is_macro;
 * an #include FILE frame also sets owns_buf=1, so freeing it mid-parse was a UAF
 * of ALL post-loop source: a for-loop WITH a step near the included file's end
 * then re-lexed freed heap -> "unexpected character" / 0x02).  The #included
 * helper's last construct is exactly such a for-with-step; if this compiles AND
 * sumto() computes correctly, the include buffer stayed alive.  Returns 42. */
#include "incstepfor_inc.h"

int main()
{
	if (sumto(5) != 15)   return 1;   /* 1+2+3+4+5  = 15 */
	if (sumto(10) != 55)  return 2;   /* 1..10      = 55 */
	return 42;
}

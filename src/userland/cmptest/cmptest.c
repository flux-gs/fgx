/* cmptest — minimal fcc repro probe for the elvis redraw MARK_UNSET bug.
 * MARK = long; MARK_UNSET = (long)0.  cursor = 0x800 (low=0x0800, high=0x0000).
 * elvis redraw.c:932 does `if (curs == MARK_UNSET)`.  If fcc's long-equality
 * only compares the high word, 0x00000800 == 0 wrongly reads TRUE. */
#include <stdio.h>

long gcur = 0x800L;

static void chk(long c, char *tag)
{
    if (c == 0L)
        printf("%s: c==0 -> UNSET (BUG if c!=0)\n", tag);
    else
        printf("%s: c!=0 -> REAL  lo=%d\n", tag, (int)c);
}

int main()
{
    long loc;
    chk(gcur, "param_global");     /* 0x800 as a long param */
    chk(0x800L, "param_literal");  /* literal 0x800 */
    loc = 0x800L;
    if (loc == 0L) printf("local: loc==0 -> UNSET (BUG)\n");
    else           printf("local: loc!=0 -> REAL\n");
    chk(0L, "param_zero");         /* control: really zero */
    return 0;
}

/* pfsign.c — correctness queue 7: G-PF2, space-padded negative sign.
 * printf("%6d", -42) must give "   -42" (pad THEN sign), while zero-pad
 * keeps sign-first ("-00042") and left-justify is unchanged ("-42   ").
 * Checked via sprintf into a buffer (same pf_run path).  All standard C
 * — clang cross-checks the exit.  Exit 42. */
#include <stdio.h>
char buf[16];

int main()
{
    int r = 0;

    sprintf(buf, "%6d", -42);
    if (buf[0] == ' ' && buf[1] == ' ' && buf[2] == ' ' &&
        buf[3] == '-' && buf[4] == '4' && buf[5] == '2' && buf[6] == 0)
        r += 20;

    sprintf(buf, "%06d", -42);
    if (buf[0] == '-' && buf[1] == '0' && buf[2] == '0' &&
        buf[3] == '0' && buf[4] == '4' && buf[5] == '2')
        r += 10;

    sprintf(buf, "%-6dX", -42);
    if (buf[0] == '-' && buf[1] == '4' && buf[2] == '2' &&
        buf[3] == ' ' && buf[5] == ' ' && buf[6] == 'X')
        r += 8;

    sprintf(buf, "%8ld", -70000L);
    if (buf[0] == ' ' && buf[1] == ' ' && buf[2] == '-' && buf[3] == '7')
        r += 4;

    return r;                    /* 20+10+8+4 = 42 */
}

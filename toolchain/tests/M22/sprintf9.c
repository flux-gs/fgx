/* M22: sprintf with 9 varargs — runtime regression for the G44 libc_args
 * cap raise (7 -> 9).  stevie's smsg() forwards 9 args to sprintf; before
 * G44 this didn't compile, and an under-sized libc_args buffer would drop
 * or corrupt the high args.  Direct byte checks (no helper string) so a
 * nonzero return pinpoints the first wrong position:
 *   10 = buf[0]  (empty/dest not delivered)   13/14 = 9th arg dropped
 *   0  = "11.22.33.44.55.66.77.88.99" exactly. */
#include <stdio.h>

char buf[40];

int
main()
{
    sprintf(buf, "%d.%d.%d.%d.%d.%d.%d.%d.%d",
            11, 22, 33, 44, 55, 66, 77, 88, 99);

    if (buf[0]  != '1') return 10;   /* arg 1 */
    if (buf[2]  != '.') return 11;
    if (buf[12] != '5') return 12;   /* arg 5 */
    if (buf[24] != '9') return 13;   /* arg 9, first digit */
    if (buf[25] != '9') return 14;   /* arg 9, second digit */
    if (buf[26] != 0)   return 15;   /* terminator */
    return 0;
}

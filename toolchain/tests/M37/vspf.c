/* vsprintf + bcopy (the 2.11BSD curses surface).  vsprintf formats through
 * a CALLER-BUILT va_list: fmtit is empty-paren-declared (variadic), K&R
 * defined with (fmt, args), and hands &args to vsprintf — the 4.3BSD
 * printw/_sprintw idiom, byte-identical to <stdarg.h>'s walk under the
 * uniform R-to-L stack ABI.  bcopy is BSD arg order (src, dst, len) and
 * overlap-safe both directions.  Exits 42 iff all three checks pass
 * (20 + 11 + 11). */
#include <string.h>
#include <stdio.h>

char gbuf[40];
char ov[8];

int fmtit();

int
main()
{
    int r = 0;
    int i;

    fmtit("%s-%d", "ab", 7);
    if (strcmp(gbuf, "ab-7") == 0)
        r += 20;

    for (i = 0; i < 8; i++)
        ov[i] = 'A' + i;                /* ABCDEFGH */
    bcopy(ov, ov + 2, 5);               /* dst>src overlap -> ABABCDEH */
    if (ov[2] == 'A' && ov[6] == 'E' && ov[7] == 'H')
        r += 11;
    bcopy(ov + 5, ov, 2);               /* forward -> DEABCDEH */
    if (ov[0] == 'D' && ov[1] == 'E')
        r += 11;
    return r;
}

int
fmtit(fmt, args)
char *fmt;
int args;
{
    return vsprintf(gbuf, fmt, (char *)&args);
}

/* FGX-Origin: original -- FGX code.  The arithmetic is transcribed from this
 * tree's own libc (toolchain/lib/libc_c/stat.c's __lc_epoch), as kern_time.c
 * says.
 * kern_epoch.c -- a calendar date and time as seconds since the epoch.
 *
 * ONE COPY FOR EVERY MODULE THAT NEEDS IT.  kern_time reads the clock with it
 * and prodos.mod reads directory stamps with it, and they are different
 * modules with no import between them, so both links PUT this one compiled
 * file.  It holds no state, which is what makes that safe.
 *
 * The assumptions are kern_time.c's: leap years are `year & 3` (exact for
 * 1970-2099), the pre-1970 leap count is `(yp + 1) >> 2` because 1972 is the
 * first, and local time IS the epoch because FGX has no timezone.
 */

#include "fsparam.h"

/* kern_epoch -- seconds since 1970 for year (1970-2099), mon (1-12), day
 * (1-31), hour, min and sec; 0 for a date outside that range, which every
 * caller reads as "no time". */
long
kern_epoch(year, mon, day, hour, min, sec)
int year;
int mon;
int day;
int hour;
int min;
int sec;
{
    int  yp;
    int  i;
    long days;

    if (year < 1970 || year > 2099)
        return (0L);
    if (mon < 1 || mon > 12 || day < 1 || day > 31)
        return (0L);

    yp   = year - 1970;
    days = (long)yp * 365L + (long)((yp + 1) >> 2);
    for (i = 1; i < mon; i++) {
        if (i == 2)
            days = days + 28L;
        else if (i == 4 || i == 6 || i == 9 || i == 11)
            days = days + 30L;
        else
            days = days + 31L;
    }
    days = days + (long)(day - 1);
    if ((year & 3) == 0 && mon >= 3)
        days = days + 1L;
    return (days * 86400L + (long)hour * 3600L + (long)min * 60L + (long)sec);
}

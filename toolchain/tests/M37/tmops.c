/* H1-date: gmtime/localtime/asctime over the ctime civil math (static
 * cells, BSD contract).  Epoch 1782829207 = Tue Jun 30 14:20:07 2026
 * (yday: 31+28+31+30+31+29 = 180... Jan..May = 151, +29 = day-of-year 180
 * 0-based); 1709208000 = Thu Feb 29 2024 12:00 UTC (leap) -- noon, so
 * localtime is Feb 29 in any zone within 12 hours of UTC.  gettimeofday
 * fills the seconds, microseconds below a million, and the kernel's zone.
 * 10+10+10+12 = 42. */
#include <time.h>
#include <sys/time.h>

int streq(char *s, char *t)
{
    int i = 0;
    while (s[i] && s[i] == t[i]) i++;
    return s[i] == t[i];
}

long e0 = 1782829207L;
long e1 = 1709208000L;
struct timeval gtv;
struct timezone gtz;

int main(void)
{
    struct tm *tp;
    int r = 0;

    tp = gmtime(&e0);
    if (tp->tm_year == 126 && tp->tm_mon == 5 && tp->tm_mday == 30 &&
        tp->tm_hour == 14 && tp->tm_min == 20 && tp->tm_sec == 7 &&
        tp->tm_wday == 2 && tp->tm_yday == 180 && tp->tm_isdst == 0)
        r += 10;
    if (streq(asctime(tp), "Tue Jun 30 14:20:07 2026\n")) r += 10;
    tp = localtime(&e1);
    if (tp->tm_mon == 1 && tp->tm_mday == 29 && tp->tm_year == 124 &&
        tp->tm_wday == 4 && tp->tm_yday == 59)
        r += 10;
    if (streq(ctime(&e1), asctime(localtime(&e1)))) {
        gtz.tz_minuteswest = 99;
        if (gettimeofday(&gtv, &gtz) == 0 && gtv.tv_sec > 1700000000L &&
            gtv.tv_usec >= 0 && gtv.tv_usec < 1000000L &&
            gtz.tz_minuteswest != 99)
            r += 12;
    }
    return r;
}

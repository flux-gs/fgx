/* H1: ctime(3) -- epoch -> "Www Mmm dd hh:mm:ss yyyy\n" (static cell).
 * FGX-only (MAME oracle).  ctime is localtime's, and localtime takes its zone
 * from TZ, else /etc/localtime, which an image built with FGX_TZ or .fgx_tz
 * sets to that zone; so the fixture names its zone first, as FGX's date(1)
 * does for -u (src/userland/date/date.c).  Expectations computed by hand
 * (UTC): epoch 0 = Thu Jan  1 1970; 1767225600 = Thu Jan  1 2026;
 * 1709164800 = Thu Feb 29 2024 (leap); 1782829207 = Tue Jun 30 14:20:07
 * 2026 -- an AFTERNOON time: secs-in-day 51607 > 32767 overflowed the old
 * int cell and printed "00:-42:-16" (H1 ls).  10+10+10+12 = 42. */
#include <time.h>

int setenv();

int streq(char *s, char *t)
{
    int i = 0;
    while (s[i] && s[i] == t[i]) i++;
    return s[i] == t[i];
}

long e0 = 0;
long e1 = 1767225600L;
long e2 = 1709164800L;
long e3 = 1782829207L;

int main(void)
{
    int r = 0;

    setenv("TZ", "GMT", 1);

    if (streq(ctime(&e0), "Thu Jan  1 00:00:00 1970\n")) r += 10;
    if (streq(ctime(&e1), "Thu Jan  1 00:00:00 2026\n")) r += 10;
    if (streq(ctime(&e2), "Thu Feb 29 00:00:00 2024\n")) r += 10;
    if (streq(ctime(&e3), "Tue Jun 30 14:20:07 2026\n")) r += 12;
    return r;
}

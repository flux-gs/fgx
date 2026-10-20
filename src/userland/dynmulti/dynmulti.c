/*
 * dynmulti -- shared libc SP5's multi-segment probe: main in code segment
 * 0 calls two functions linked into code segments 2 and 3, each of which
 * calls libc and reads libc data, so every code segment carries import
 * sites.  `DMU <check> ok' or `DMU FAIL <check>' per check, then `DMU ok'.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>

extern int seg2_fn(), seg3_fn();
static int fails;

static void
chk(c, what)
int c;
char *what;
{
    printf(c ? "DMU %s ok\n" : "DMU FAIL %s\n", what);
    if (!c)
        fails++;
}

int
main()
{
    char b[16];

    errno = 0;
    chk(seg2_fn(b) == 5 && strcmp(b, "seg2!") == 0, "seg2");
    chk(seg3_fn() == 0, "seg3");
    if (!fails)
        printf("DMU ok\n");
    return fails;
}

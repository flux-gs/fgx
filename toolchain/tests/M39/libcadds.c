/* M39 (frotz port): the libc/header additions the port pulled in.
 * puts (ANSI: string + newline to stdout, nonnegative on success),
 * memmove (overlap-safe both directions, returns dest), atof's stdlib.h
 * prototype (double, fcc's 64-bit IEEE double), FILENAME_MAX in stdio.h,
 * and time_t typedef'd by <time.h> alone (no <sys/types.h> first --
 * exactly how frotz's dumb_frotz.h includes land). */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

static char ov[8] = "abcdef";

int main(void)
{
    time_t t0;                      /* compiles: time.h owns time_t now */
    char nm[FILENAME_MAX];
    char *r;
    double d;

    t0 = 0;
    nm[0] = (char)(t0 & 0xFF);      /* keep both live */

    if (puts("m39") < 0) return 1;

    r = (char *)memmove(ov + 2, ov, 4);      /* fwd overlap: "ababcd" */
    if (r != ov + 2) return 2;
    if (strcmp(ov, "ababcd") != 0) return 3;
    memmove(ov, ov + 2, 4);                  /* back overlap: "abcdcd" */
    if (strcmp(ov, "abcdcd") != 0) return 4;

    d = atof("21.0");
    if (d != 21.0) return 5;

    return 42 + nm[0];              /* t0 == 0, so exactly 42 */
}

/* A dynamic link's fixture (shared libc SP3 step 3): a call, a pointer
 * cell, data with and without an addend, a far helper. */
#include <stdio.h>
#include <string.h>
#include <errno.h>
static char *v[] = { "b", "a" };
int *ep = &errno;
int
main()
{
    long q = 1000L;
    int n = 7;
    *ep = 0;
    errno = 0;
    qsort(v, 2, sizeof v[0], strcmp);
    q = q / (long)n;
    printf("%s%s %ld\n", v[0], v[1], q);
    fflush(stdout);
    return errno;
}

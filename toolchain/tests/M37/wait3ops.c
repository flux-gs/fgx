/* wait3(2): the BSD reap-with-usage, added for the tcsh port (sh.proc's job
 * control calls it, and it was the one unresolved symbol in the tcsh link).
 *
 * Two things are pinned here, and the first is the one that has bitten twice:
 *
 * 1. STATUS INTO A STACK LOCAL.  tcsh does `wait3(&w, ...)` with a stack-local
 *    `union wait w`, so &w is a bank-0 hardware-stack address.  Handing that
 *    pointer to the kernel DROPS its bank and the status lands at that offset
 *    in the caller's DATA bank instead -- which is exactly how every bsh `$?`
 *    read 0 (fixed 6343b62f), and it is invisible if the fixture uses a global.
 *    So `st` below is deliberately a LOCAL, not a global.
 *
 * 2. RUSAGE IS ZEROED, NOT LEFT ALONE.  FGX keeps no per-process resource
 *    accounting.  BSD callers read the struct unconditionally, so libc zeroes
 *    it rather than handing back stack garbage.  `ru` is poisoned with $5A
 *    first, so "left untouched" and "zeroed" are distinguishable -- without the
 *    poison a zeroed stack would pass either way.
 *
 * The argv table and its strings MUST live in the data bank (the kernel reads
 * them through the caller's DBR), hence globals -- same as spawnops.
 *
 * FGX-only (MAME oracle).  8+8+8+8+10 = 42.
 */
#include <sys/resource.h>

char nm[] = "/bin/true";
int  argv_tab[2];

int main(void)
{
    struct rusage ru;               /* LOCAL on purpose (bank case) */
    int   st;                       /* LOCAL on purpose (bank case) */
    int   pid, r = 0, i, poisoned = 0, zeroed = 1;
    char *p;

    argv_tab[0] = (int)(unsigned long)nm;
    argv_tab[1] = 0;

    p = (char *)&ru;
    for (i = 0; i < (int)sizeof(struct rusage); i++)
        p[i] = 0x5A;
    for (i = 0; i < (int)sizeof(struct rusage); i++)
        if (p[i] == 0x5A) poisoned = 1;
    if (poisoned) r += 8;           /* the poison really took */

    st  = 0x1234;                   /* must be OVERWRITTEN, not just 0 */
    pid = spawnv(nm, argv_tab);
    if (pid > 0) r += 8;

    if (wait3(&st, 0, &ru) == pid) r += 8;   /* reaps, and returns the pid */
    if (st == 0)                   r += 8;   /* /bin/true exits 0, into a LOCAL */

    for (i = 0; i < (int)sizeof(struct rusage); i++)
        if (p[i] != 0) zeroed = 0;
    if (zeroed) r += 10;            /* rusage came back zero-filled */

    return r;
}

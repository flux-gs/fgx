/* M22: popen()/pclose() stubs.  FGX has no pipe / fork-to-a-program yet, so
 * popen() returns NULL (a BSD caller like elvis elvprsv mail() checks it and
 * degrades gracefully) and pclose() returns -1.  Guards the fcc libc-table
 * registration + the c_popen/c_pclose shims.  Returns 42. */
#include <stdio.h>

int main()
{
    FILE *m;

    m = popen("mail root", "w");
    if (m != 0)          return 1;   /* stub must fail cleanly (NULL) */
    if (pclose(m) != -1) return 2;   /* companion stub returns -1 */
    return 42;
}

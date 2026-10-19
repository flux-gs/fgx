/* M22: sprintf into a malloc'd buffer that may live OUTSIDE the data (DBR)
 * bank.  Regression for the sprintf-DBR-relative bug: libc sprintf wrote the
 * caller's buffer via `STA (dp)` (DBR-relative), ignoring the buffer's actual
 * bank.  malloc returns own-bank memory (A.lo=bank, Y=offset) that can sit in
 * a different 64K than DBR, so every byte landed in the wrong bank and the
 * buffer stayed at its sentinel.  The fix: fcc stashes the destination's bank
 * in _fcc_pf_outbank (like the fmt bank) and libc writes via bank-aware
 * `STA [dp],Y`.  The sentinel store and strcmp both go through the bank-aware
 * far-pointer path (which already worked), so a mismatch isolates sprintf.
 * Returns 42 iff the formatted digits overwrote the sentinel and round-trip. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main()
{
    char *p;
    p = malloc(16);
    if (!p)
        return 1;
    p[0] = '?';                 /* sentinel via the (bank-aware) store path */
    p[1] = 0;
    sprintf(p, "%d", 4242);     /* must write through the buffer's real bank */
    if (strcmp(p, "4242") != 0)
        return 1;
    return 42;
}

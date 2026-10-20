/* `long i = 0` for-init: does the high word of i actually get zeroed,
 * even when _fcc_long_hi is non-zero from a prior op? */

#include <stdio.h>

int main(void) {
    int s = 0;
    /* Prime _fcc_long_hi with a non-zero value via prior long math. */
    long dummy = 65536L + 1L;  /* high word = 1 */
    s = (int)dummy;            /* keep dummy alive */
    /* Now the for-init `long i = 0`.  If init only writes the low word,
     * i.high stays at 1 and `i < 6` is false from the start. */
    for (long i = 0; i < 6; i = i + 1) {
        s = s + 7;
    }
    printf("s=%d\n", s);  /* want 1 + 42 = 43 */
    return 0;
}

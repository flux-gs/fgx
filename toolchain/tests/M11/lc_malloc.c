/* malloc returns a usable long-ptr — writes through it land at the
 * actual heap byte, and stored bytes round-trip via %s.  Exercises
 * the bank-byte path through c_malloc, store-local, %s arg pushing
 * and pf_emit_str's long-indirect read. */

#include <stdio.h>
#include <stdlib.h>

int main(void) {
    char *p;
    char *q;
    int  a, b;

    p = malloc(8);
    if (!p) { printf("alloc fail p\n"); return 1; }
    p[0] = 'X'; p[1] = 'Y'; p[2] = 0;

    q = malloc(8);
    if (!q) { printf("alloc fail q\n"); return 1; }
    q[0] = 'Z'; q[1] = 0;

    a = p[0];
    b = p[1];
    if (a != 'X' || b != 'Y') {
        printf("clobbered a=%d b=%d\n", a, b);
        return 1;
    }
    printf("p=%s q=%s a=%d b=%d\n", p, q, a, b);

    free(p);
    free(q);
    printf("free ok\n");
    return 0;
}

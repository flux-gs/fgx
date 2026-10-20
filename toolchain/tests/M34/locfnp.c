/* locfnp.c — correctness queue 5: LOCAL fn-ptr arrays (the B-7 deferred
 * item, gated on B-5-local which has since landed).  Both declarator
 * forms (typedef'd `cb_t arr[N]` and direct `int (*arr[N])()`), element
 * stores, direct indexed call, and the stash idiom.  Local scalar
 * pointer arrays are pinned too (registry-stale: they already worked).
 * All standard C — clang cross-checks the exit.  Exit 42. */
typedef int (*cb_t)();

int f2()
{
    return 2;
}

int add8(int v)
{
    return v + 8;
}

int f30()
{
    return 30;
}

char b1[2];
char b2[2];

int main()
{
    cb_t arr[2];
    int (*darr[2])();
    cb_t f;
    char *pa[3];
    int r = 0;

    arr[0] = f2;
    arr[1] = add8;
    r += arr[1](20);         /* direct indexed call: 28 */
    f = arr[0];
    r += f();                /* stash idiom: +2 */

    darr[0] = f30;
    darr[1] = f2;
    r += darr[0]();          /* direct form: +30 */

    pa[0] = b1;
    pa[1] = b2;
    b2[0] = 2;
    r += pa[1][0] - 20;      /* local ptr-array pin: 2 - 20 = -18 */

    return r;                /* 28+2+30-18 = 42 */
}

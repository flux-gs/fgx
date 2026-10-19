/* uresid.c — correctness queue 3: the A-1 unsigned RESIDUALS closed.
 *   3a: a call through a FUNCTION POINTER carries the target's unsigned
 *       return (FnSig now keys+carries ret_unsigned) — compares and
 *       division on the result pick the unsigned helpers.
 *   3b: compound assign through an unsigned-pointee deref (*p /= v)
 *       uses the pointee's signedness.
 * All standard C — clang cross-checks at the same exit.  Exit 42. */
typedef unsigned int (*uf_t)();

unsigned int mk40k()
{
    return 40000;
}

uf_t gfp;
unsigned int gu;

int main()
{
    int r = 0;
    uf_t lfp;
    unsigned int *p;

    gfp = mk40k;
    lfp = mk40k;

    if (gfp() > 30000) r += 10;          /* signed would say negative */
    r += (int)(lfp() / 10000);           /* unsigned div: +4 */
    if (mk40k() >= 40000) r += 10;       /* direct call (regression) */

    gu = 40000;
    p = &gu;
    *p /= 2500;                          /* unsigned pointee: 16 */
    r += (int)gu;

    gu = 50000;
    *p >>= 12;                           /* logical shift: 12 */
    r += (int)gu - 10;                   /* +2 */

    return r;                            /* 10+4+10+16+2 = 42 */
}

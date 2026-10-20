/* E1 op= E2 WITH AN UNSIGNED INT AND A LONG: the same conversions as E1 op E2.
 *
 * K&R A.7.17 (p.169): "E1 op= E2 is equivalent to E1 = E1 op (E2)".  A.6.5
 * (p.160): a long and an unsigned int meet as long int, since a long can
 * represent every unsigned int here, so the operation is a SIGNED one and the
 * unsigned operand zero-extends.  An unsigned divide or a sign-extended
 * 40000u gives a different answer in every check below.
 */
unsigned int U;
unsigned long UL;
long L;
long *PL;

int main()
{
    int acc;
    long l;

    acc = 0;
    U = 40000;
    PL = &l;

    L = -80000L;
    L /= U;                                  /* signed: -2, not 107372 */
    if (L == -2L) acc += 1;
    L = 100000L;
    L -= U;                                  /* 60000, not 125536 */
    if (L == 60000L) acc += 2;
    l = -80000L;
    l /= U;                                  /* a local */
    if (l == -2L) acc += 4;
    l = -80000L;
    *PL /= U;                                /* through a pointer */
    if (l == -2L) acc += 8;
    l = 5L;
    l += U;
    if (l == 40005L) acc += 16;
    UL = 0xFFFFFFFF;
    UL /= U;                                 /* unsigned long stays unsigned */
    if (UL == 107374L) acc += 32;
    l = 7L;
    l %= U;
    if (l == 7L) acc += 64;
    l = -1L;
    l *= U;                                  /* -40000 */
    if (l == -40000L) acc += 128;

    return acc;                              /* 255 */
}

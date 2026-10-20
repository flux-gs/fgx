/* AN UNSIGNED INT MEETS A LONG: it zero-extends, and the operation is a
 * SIGNED long one.
 *
 * K&R A.6.5 (p.160): "if one operand is long int and the other is unsigned
 * int, the effect depends on whether a long int can represent all values of
 * an unsigned int; if so, the unsigned int operand is converted to long int".
 * Here int is 16 bits and long 32, so it can.  A.6.2 (p.159): converting to a
 * wider type means "zero-filling unsigned values and sign-extending signed
 * values".  And p.160: "shorter unsigned types, when combined with a larger
 * signed type, do not propagate the unsigned property to the result type".
 * Each check below fails if 40000u sign-extends or if the op goes unsigned.
 */
unsigned int  U, U2;
long          L, L2;
unsigned long UL;

int main()
{
    int acc;

    acc = 0;
    U  = 40000;
    U2 = 3;
    L  = -1L;
    L2 = 5L;
    UL = 0xFFFFFFFF;

    if (U == 40000) acc += 1;                /* 40000 is a long constant */
    if (40000 == U) acc += 2;                /* the long on the left */
    if (L < U) acc += 4;                     /* signed: -1 < 40000 */
    if (!(U < L)) acc += 8;
    if (U + 70000L == 110000L) acc += 16;    /* widened, not 44464 */
    if (70000L - U == 30000L) acc += 32;
    if (UL > 1L) acc += 64;                  /* unsigned long stays unsigned */
    if (U2 - L2 < 0L) acc += 128;            /* 3 - 5 is a signed -2 */

    return acc;                              /* 255 */
}

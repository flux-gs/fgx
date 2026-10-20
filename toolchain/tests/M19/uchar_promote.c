/* AN UNSIGNED CHAR PROMOTES TO A SIGNED INT.
 *
 * K&R A.6.1 (p.159): "A character, a short integer, or an integer bit-field,
 * all either signed or not ... If an int can represent all the values of the
 * original type, then the value is converted to int".  An int holds every
 * unsigned char value, so `c' in an expression is a SIGNED int: `c < -1' is
 * false for c = 200, and c / -2 is -100.  An unsigned comparison or division
 * gives the other answer in every check below.
 */
unsigned char C;
unsigned char A[2];
struct S { int pad; unsigned char m; } G;

int main()
{
    int acc;
    unsigned char lc;
    int neg;

    acc = 0;
    neg = -1;
    C = 200;
    lc = 200;
    A[1] = 200;
    G.m = 200;

    if (!(C < -1)) acc += 1;                 /* global */
    if (!(lc < neg)) acc += 2;               /* local, int variable */
    if (C / -2 == -100) acc += 4;            /* signed division */
    if (!(A[1] < neg)) acc += 8;             /* array element */
    if (!(G.m < neg)) acc += 16;             /* struct member */
    if (lc % -7 == 4) acc += 32;             /* signed modulus: 200 % -7 */
    if ((C > neg) == 1) acc += 64;
    if (-C < 0) acc += 128;                  /* -200, an int */

    return acc;                              /* 255 */
}

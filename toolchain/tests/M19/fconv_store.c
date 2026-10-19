/* A FLOAT MEETS AN INTEGER IN AN ASSIGNMENT: the value converts, never the
 * bits -- in every store spelling and in op=.
 *
 * K&R A.7.17 (p.169): in a simple assignment where "both operands have
 * arithmetic type ... the right operand is converted to the type of the left
 * by the assignment", and "E1 op= E2 is equivalent to E1 = E1 op (E2)".
 * A.6.3 (p.159): "When a value of floating type is converted to integral
 * type, the fractional part is discarded".  A.6.5: a float operand makes the
 * arithmetic float's, so `i *= 1.5' multiplies in float and then truncates,
 * which is not `i * (int)1.5'.  Every expected value below is one a raw bit
 * copy or an integer operation cannot produce.
 */
struct S { int pad; int i; long l; float f; };

float F, FH;
long  GL;
int   GI;
int   GA[3];
struct S GS;
struct S *GP;
long  *PL;

int main()
{
    int acc, k;
    long ll;
    struct S ls;

    acc = 0;
    k = 1;
    F  = 2.75;
    FH = 70000.5;
    GP = &ls;
    PL = &ll;

    GI = F;                                  /* global int     <- float */
    if (GI == 2) acc += 1;
    GA[k] = F;                               /* array element  <- float */
    if (GA[1] == 2) acc += 2;
    GP->i = F;                               /* p->m           <- float */
    GS.l = FH;                               /* s.m (long)     <- float */
    if (GP->i == 2 && GS.l == 70000L) acc += 4;
    GL = 70000L;
    GP->f = GL;                              /* p->m (float)   <- long */
    if ((long)GP->f == 70000L) acc += 8;

    GI = 3;
    GI *= 1.5;                               /* 4.5 -> 4, not 3 */
    if (GI == 4) acc += 16;
    GS.l = 100001L;
    GS.l *= 1.5;                             /* 150001.5 -> 150001 */
    if (GS.l == 150001L) acc += 32;

    ll = 70000L;
    *PL += 70000L;                           /* all four bytes, with carry */
    if (ll == 140000L) acc += 64;
    ll = 3L;
    if ((*PL = F) == 2L) acc += 128;         /* value position through *p */

    return acc;                              /* 255 */
}

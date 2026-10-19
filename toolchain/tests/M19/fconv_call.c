/* A FLOAT MEETS AN INTEGER WHERE K&R SAYS "AS BY ASSIGNMENT": a return, a
 * prototyped argument and a static initializer.
 *
 * K&R A.9.6 (p.184): "The expression is converted, as by assignment, to the
 * type returned by the function in which it appears."  A.7.3.2 (p.163): for a
 * new-style declaration "the arguments are converted, as if by assignment, to
 * the types of the corresponding parameters".  A.8.7 (p.179): the initializer
 * "expression is assigned to the object".  A.6.3: the fractional part is
 * discarded, toward zero, so -2.75 becomes -2.
 */
int   gi = 2.5;
long  gl = -70000.9;
char  gc = 65.9;

float F, FN;
long  L;

int   ri()        { return FN; }
float rf()        { return L; }
int   ti(int x)   { return x; }
long  tl(long x)  { return x; }
float tf(float x) { return x; }

int main()
{
    int acc;

    acc = 0;
    F  = 7.9;
    FN = -2.75;
    L  = 70000L;

    if (ri() == -2) acc += 1;
    if ((long)rf() == 70000L) acc += 2;
    if (ti(F) == 7) acc += 4;
    if (tl(F) == 7L) acc += 8;
    if ((long)tf(L) == 70000L) acc += 16;
    if (gi == 2) acc += 32;
    if (gl == -70000L) acc += 64;
    if (gc == 65) acc += 128;

    return acc;                              /* 255 */
}

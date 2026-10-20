/* B-6 Phase 2b: float multiply (_fcc_fmul) + negate (_fcc_fneg).
 * Exercises float*float (variables and literals), int->float promotion in a
 * mixed product, and unary float negation.  Returns 42 iff all correct. */
int main(void)
{
    float a, b;

    a = 1.5;
    b = 2.0;
    if ((int)(a * b)   != 3)  return 1;     /* 1.5 * 2.0 = 3.0          */
    if ((int)(2.5 * 4.0) != 10) return 2;   /* literal product = 10.0   */

    a = 2.0;
    if ((int)(-a)      != -2) return 3;      /* fneg: -2.0 -> -2         */

    b = 4.0;
    if ((int)(a * 3)   != 6)  return 4;      /* mixed: 2.0 * (float)3    */

    a = 6.0;
    b = 7.0;
    if ((int)(a * b)   == 42) return 42;     /* 6.0 * 7.0 = 42.0 -> 42   */
    return 5;
}

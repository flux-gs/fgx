/* B-6 Phase 2c: float add (_fcc_fadd) and subtract (_fcc_fsub).
 * Exercises exponent alignment, same-sign add, opposite-sign subtract with
 * left-normalization, exact cancellation, and int->float promotion in a
 * mixed sum.  Returns 42 iff all correct. */
int main(void)
{
    float a, b;

    a = 1.5; b = 2.0;
    if ((int)(a + b)     != 3)  return 1;   /* 3.5 -> 3 (align + add)      */
    if ((int)(5.0 - 3.0) != 2)  return 2;   /* 2.0 (subtract + normalize)  */
    if ((int)(2.5 + 2.5) != 5)  return 3;   /* 5.0 (carry into bit 24)     */

    a = 10.0; b = 0.5;
    if ((int)(a - b)     != 9)  return 4;   /* 9.5 -> 9                     */
    if ((int)(a + 32)    != 42) return 5;   /* mixed 10.0 + (float)32      */

    a = 3.0;
    if ((int)(a - 3.0)   != 0)  return 6;   /* exact cancellation -> 0     */

    a = 2.0; b = 40.0;
    if ((int)(a + b)     == 42) return 42;  /* 42.0 -> 42                  */
    return 7;
}

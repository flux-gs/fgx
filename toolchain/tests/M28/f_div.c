/* B-6 Phase 2e: float division (_fcc_fdiv).
 * Exercises quotient >= 1 and < 1 (normalize-down), an exact a/a == 1.0,
 * a fractional result fed back through a multiply, and int->float promotion.
 * Returns 42 iff all correct. */
int main(void)
{
    float a, b;

    a = 3.0; b = 2.0;
    if ((int)(a / b)       != 1)  return 1;   /* 1.5 -> 1                 */
    if ((int)(7.0 / 2.0)   != 3)  return 2;   /* 3.5 -> 3                 */

    a = 84.0; b = 2.0;
    if ((int)(a / b)       != 42) return 3;   /* 42.0                     */

    a = 1.0; b = 4.0;
    if ((int)((a / b) * 8.0) != 2) return 4;  /* 0.25 (q<1) * 8 = 2.0     */

    a = 10.0;
    if ((int)(a / a)       != 1)  return 5;   /* exact 1.0 (no truncation)*/

    a = 100.0; b = 8.0;
    if ((int)(a / b)       != 12) return 6;   /* 12.5 -> 12               */

    a = 84.0; b = 2.0;
    if ((int)(a / b)       == 42) return 42;
    return 7;
}

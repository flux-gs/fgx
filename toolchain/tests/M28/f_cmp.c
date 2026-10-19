/* B-6 Phase 2d: float comparisons (_fcc_flt/fgt/fle/fge/feq/fne).
 * Covers ordering with equal exponents, equality, equal-operand <=/>=,
 * negative-vs-positive, and negative-vs-negative ordering.  Returns 42
 * iff every comparison is correct. */
int main(void)
{
    float a, b;

    a = 1.5; b = 2.0;
    if (!(a < b))  return 1;
    if (!(b > a))  return 2;
    if (a > b)     return 3;
    if (!(a <= b)) return 4;
    if (!(b >= a)) return 5;
    if (a == b)    return 6;
    if (!(a != b)) return 7;

    a = 2.0;                 /* a == b now */
    if (!(a == b)) return 8;
    if (a != b)    return 9;
    if (!(a <= b)) return 10;
    if (!(a >= b)) return 11;

    a = -1.0; b = 1.0;
    if (!(a < b))  return 12;     /* negative < positive */
    if (a > b)     return 13;

    a = -2.0; b = -1.0;
    if (!(a < b))  return 14;     /* -2.0 < -1.0 */
    if (a >= b)    return 15;

    if (3.0 < 2.0) return 16;
    return 42;
}

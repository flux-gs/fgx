/* Audit: all 6 comparison ops + signed-cmp with negatives.
 * Each true branch contributes a distinct power-of-2-ish weight; if any
 * helper is broken (e.g., <= inverted via EOR), the sum diverges from 42. */

int main()
{
    int s;
    int a;
    int b;
    int n;
    s = 0;
    a = 5;
    b = 7;
    n = 0 - 3;        /* -3 without literal minus parser */

    if (a <  b)  s = s + 1;   /* 5 < 7   true  +1 */
    if (b >  a)  s = s + 2;   /* 7 > 5   true  +2 */
    if (a <= a)  s = s + 4;   /* 5 <= 5  true  +4 */
    if (a >= a)  s = s + 8;   /* 5 >= 5  true  +8 */
    if (a == a)  s = s + 16;  /* 5 == 5  true  +16 */
    if (a != b)  s = s + 4;   /* 5 != 7  true  +4 */
    if (n <  a)  s = s + 4;   /* -3 < 5  true (signed) +4 */
    if (a >  n)  s = s + 3;   /* 5 > -3  true (signed) +3 */
    return s;                 /* 1+2+4+8+16+4+4+3 = 42 */
}

/* B-6 follow-up: round-to-nearest-even in the softfloat runtime.  Each check
 * uses a result whose correctly-rounded (RNE) value differs from truncation;
 * the comparison literal is the RNE value, so the fixture returns 42 only when
 * fdiv/fmul/fadd/ltof all round to nearest-even.  A comparison literal that is
 * not exactly a float carries the F suffix: an unsuffixed one is a double
 * (K&R A.2.5.3) and would widen the comparison.  Host-verified bit patterns:
 *   1.0/3.0          = 0x3EAAAAAB  (trunc 0x3EAAAAAA)
 *   2.0/3.0          = 0x3F2AAAAB  (trunc 0x3F2AAAAA)
 *   0.1*3.0 = 0.1+0.2 = 0x3E99999A (trunc 0x3E999999)
 *   (float)16777219  = 0x4B800002  (an exact tie -> round to even; trunc ..01)
 *   100000.0-0.0033  = 0x47C35000  (opposite-sign subtract; trunc 0x47C34FFF)
 * Variables (not literals) force runtime evaluation rather than const-folding. */
int main(void)
{
    float a, b, r;
    long  l;

    a = 1.0; b = 3.0;  r = a / b;
    if (r != 0.33333334f) return 1;  /* fdiv rounds up                  */

    a = 2.0; b = 3.0;  r = a / b;
    if (r != 0.6666667f)  return 2;  /* fdiv rounds up                  */

    a = 0.1; b = 3.0;  r = a * b;
    if (r != 0.3f)        return 3;  /* fmul rounds up                  */

    a = 0.1; b = 0.2;  r = a + b;
    if (r != 0.3f)        return 4;  /* fadd same-sign rounds up        */

    l = 16777219L;     r = (float)l;
    if (r != 16777220.0) return 5;   /* ltof tie -> even                */

    a = 100000.0; b = 0.0033;  r = a - b;
    if (r != 100000.0)   return 6;   /* fadd opposite-sign rounds up    */

    return 42;
}

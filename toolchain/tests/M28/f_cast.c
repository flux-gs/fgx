/* B-6 deferred: (float)long and (long)float casts (_fcc_ltof / _fcc_ftol).
 * Covers long->float (large >2^16 and small/exact), float->long (truncate
 * and a >16-bit result), and a long->float->long round-trip.  Returns 42. */
int main(void)
{
    long  l;
    float f;

    if ((float)100000L != 100000.0) return 1;   /* ltof, > 2^16          */
    if ((float)3L != 3.0)           return 2;    /* ltof, small/exact     */
    if ((long)42.5 != 42L)          return 3;    /* ftol, truncate        */
    if ((long)100000.0 != 100000L)  return 4;    /* ftol, > 16-bit result */

    l = 70000L;
    f = (float)l;
    if ((long)f != 70000L)          return 5;    /* round-trip            */

    return 42;
}

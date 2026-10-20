/* B-6 Phase 2a: int<->float conversions (_fcc_itof / _fcc_ftoi).
 * Exercises the implicit int->float conversion on store, the explicit
 * (float)int cast, and the (int)float cast (truncating toward zero).
 * Returns 42 iff every conversion round-trips correctly. */
int main(void)
{
    float a;
    int   r;

    a = 5;                 /* int -> float (itof on store): 5.0          */
    r = (int)a;            /* float -> int (ftoi): 5                      */
    if (r != 5) return 1;

    if ((int)2.0 != 2) return 2;     /* float literal -> int             */
    if ((int)9.5 != 9) return 3;     /* truncation toward zero           */

    a = (float)40;         /* explicit (float)int cast                   */
    if ((int)a + 2 != 42) return 4;  /* ftoi(40.0) = 40, + 2 = 42        */

    return 42;
}

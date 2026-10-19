/* B-6 Phase 1: float/double type foundation.
 * float is the 32-bit IEEE-754 single (sizeof 4), double the 64-bit IEEE
 * double (sizeof 8, apple/fgx#447).  Global float-literal initializers emit
 * the exact IEEE-754 bit pattern (golden-verified against host strtof and
 * strtod); the runtime return proves the type sizes (float 4, double 8,
 * float[3] 12). */
float  g_pi   = 3.14;      /* 0x4048F5C3 */
float  g_two  = 2.0;       /* 0x40000000 */
float  g_half = 0.5;       /* 0x3F000000 */
float  g_neg  = -1.5;      /* 0xBFC00000 */
double g_one  = 1.0;       /* 0x3FF0000000000000 */
float  g_arr[3];           /* uninitialised: DS 12 */

int main(void)
{
    return sizeof(float) + sizeof(double) + sizeof(g_arr) + 18;
    /* 4 + 8 + 12 + 18 = 42 */
}

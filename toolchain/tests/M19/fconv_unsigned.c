/* AN UNSIGNED VALUE CONVERTS TO AND FROM FLOAT BY VALUE, never through the
 * signed routine that reads its top bit as a sign.
 *
 * K&R A.6.3 (p.159): "When a value of integral type is converted to floating,
 * and the value is in the representable range but is not exactly
 * representable, then the result may be either the next higher or next lower
 * representable value" -- the VALUE is what converts, so 40000u is 40000.0,
 * not the -25536.0 its bits read as an int.  And "When a value of floating
 * type is converted to integral type, the fractional part is discarded; if the
 * resulting value cannot be represented in the integral type, the behavior is
 * undefined": 40000.0 is representable in unsigned int, so it converts.
 * Every expected value below is one the signed routines cannot produce.
 */
unsigned int  U;
unsigned long UL;
float         F;

float ret_u()
{
    return U;                                /* A.9.6: as by assignment */
}

float arg_f(float x)
{
    return x;
}

int main()
{
    int acc;
    float f;
    unsigned int u;
    unsigned long ul;

    acc = 0;
    U  = 40000;
    UL = 0xB2D05E00;                         /* 3,000,000,000: unsigned long */

    f = U;                                   /* assignment */
    if ((long)f == 40000L) acc += 1;
    if ((long)(float)U == 40000L) acc += 2;  /* cast */
    if ((long)(U + 0.5) == 40000L) acc += 4; /* A.6.5: U converts to float */
    if ((long)ret_u() == 40000L) acc += 8;   /* return */
    f = UL;
    if (f > 2.9e9 && f < 3.1e9) acc += 16;   /* unsigned long, top bit set */
    F = 40000.0;
    u = F;                                   /* float -> unsigned int */
    if (u == 40000) acc += 32;
    F = 3.0e9;
    ul = F;                                  /* float -> unsigned long */
    if (ul == 0xB2D05E00) acc += 64;
    if ((long)arg_f(U) == 40000L) acc += 128; /* A.7.3.2: prototyped arg */

    return acc;                              /* 255 */
}

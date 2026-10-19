/* epp.c — correctness queue 9/10 pins.
 *   E-2: #pragma / #line are no-ops; #error inside an inactive branch is
 *   inert (an ACTIVE #error dies with the message — compile-fail form,
 *   not pinnable in a running fixture).
 *   Also pins &arr[i] (global/local/argument forms) and float loop
 *   arithmetic in for() — probe-verified already working.
 * All standard C — clang cross-checks the exit.  Exit 42. */
#pragma once
#line 500
#if 0
#error this must never fire
#endif
int ga4[4];

int bump(int *p)
{
    *p = 30;
    return 4;
}

int main()
{
    int a[4];
    int *q;
    float f;
    float s = 0.0;
    int r = 0;

    q = &a[2];
    *q = 6;
    r += a[2] + bump(&ga4[3]) + ga4[3];   /* 6+4+30 = 40 */

    for (f = 0.5; f < 2.0; f = f + 1.0)
        s = s + f;
    if (s == 2.0) r += 2;                 /* 0.5+1.5 = 2.0 -> +2 */

    return r;                             /* 42 */
}

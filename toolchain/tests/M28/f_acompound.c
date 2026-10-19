/* B-6 follow-up: 4-byte compound assignment on long/float ARRAY elements
 * (arr[i] op= v).  The generic compound path loaded/stored only 16 bits, so
 * la[i] += big or fa[i] *= x clobbered the high word.  Covers global + local,
 * long + float, constant + variable index, same-type + int RHS (promoted).
 * float checks use (int) casts to dodge exact-equality.  Returns 42. */

long  lg[3];
float fg[3];

int main(void)
{
    long  ll[3];
    float fl[3];
    int   i;

    lg[0] = 100000L; lg[0] += 50000L;   /* 150000                       */
    if (lg[0] != 150000L) return 1;
    lg[1] = 200000L; lg[1] -= 5;        /* 199995 (int RHS -> long)     */
    if (lg[1] != 199995L) return 2;

    i = 2;
    lg[i] = 12345L; lg[i] += 5L;        /* lg[2] = 12350 (var index)    */
    if (lg[2] != 12350L) return 3;

    ll[0] = 80000L; ll[0] += 80000L;    /* 160000 (local)               */
    if (ll[0] != 160000L) return 4;
    ll[2] = 70000L; ll[2] += 1;         /* 70001 (int RHS)              */
    if (ll[2] != 70001L) return 5;

    fg[0] = 1.5; fg[0] += 2.0;          /* 3.5                          */
    if ((int)(fg[0] * 2.0) != 7) return 6;
    fg[1] = 10.0; fg[1] -= 2.5;         /* 7.5                          */
    if ((int)fg[1] != 7) return 7;

    fl[0] = 2.0; fl[0] *= 3.0;          /* 6.0 (local)                  */
    if ((int)fl[0] != 6) return 8;
    fl[1] = 5.0; fl[1] += 3;            /* 8.0 (int RHS -> float)       */
    if ((int)fl[1] != 8) return 9;

    return 42;
}

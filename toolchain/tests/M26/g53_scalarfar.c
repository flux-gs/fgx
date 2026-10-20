/* Frame layout: more than 255 bytes of SCALARS.  Scalars sit below
 * aggregates, so only a function whose scalars alone pass offset 255 still
 * reaches a scalar through _fcc_fp: 33 long longs (264 bytes) put x and y
 * past it, on the far path of the structured IR's local load and store.
 * Returns 42. */
int scalarfar(int k)
{
    long long q0;
    long long q1;
    long long q2;
    long long q3;
    long long q4;
    long long q5;
    long long q6;
    long long q7;
    long long q8;
    long long q9;
    long long q10;
    long long q11;
    long long q12;
    long long q13;
    long long q14;
    long long q15;
    long long q16;
    long long q17;
    long long q18;
    long long q19;
    long long q20;
    long long q21;
    long long q22;
    long long q23;
    long long q24;
    long long q25;
    long long q26;
    long long q27;
    long long q28;
    long long q29;
    long long q30;
    long long q31;
    long long q32;
    int x, y;

    q0 = 0;
    q1 = 1;
    q2 = 2;
    q3 = 3;
    q4 = 4;
    q5 = 5;
    q6 = 6;
    q7 = 7;
    q8 = 8;
    q9 = 9;
    q10 = 10;
    q11 = 11;
    q12 = 12;
    q13 = 13;
    q14 = 14;
    q15 = 15;
    q16 = 16;
    q17 = 17;
    q18 = 18;
    q19 = 19;
    q20 = 20;
    q21 = 21;
    q22 = 22;
    q23 = 23;
    q24 = 24;
    q25 = 25;
    q26 = 26;
    q27 = 27;
    q28 = 28;
    q29 = 29;
    q30 = 30;
    q31 = 31;
    q32 = 32;
    x = k;
    y = x + 6;
    return (int)(q0 + q1 + q2 + q3 + q4 + q5 + q6 + q7 + q8 + q9 + q10 + q11 + q12 + q13 + q14 + q15 + q16 + q17 + q18 + q19 + q20 + q21 + q22 + q23 + q24 + q25 + q26 + q27 + q28 + q29 + q30 + q31 + q32) - 528 + y + x;  /* 0 + 24 + 18 */
}

int main()
{
    return scalarfar(18);
}

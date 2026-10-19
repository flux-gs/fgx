/* B-6 deferred: float function parameters + float return values (4-byte ABI,
 * mirrors long).  Covers a 2-float-param function, a mixed (float,int) param
 * list with int->float promotion, and unary negate through a call.  The float
 * return is consumed directly by an (int) cast.  Returns 42 iff all correct. */
float addf(float a, float b) { return a + b; }
float scale(float x, int n)  { return x * n; }    /* n promoted to float */
float negf(float x)          { return -x; }

int main(void)
{
    if ((int)addf(1.5, 2.0)  != 3)  return 1;     /* 3.5 -> 3            */
    if ((int)addf(40.0, 2.0) != 42) return 2;     /* 42.0               */
    if ((int)scale(3.0, 14)  != 42) return 3;     /* 3.0 * 14 = 42.0    */
    if ((int)negf(-42.0)     != 42) return 4;     /* -(-42.0) = 42.0    */
    return 42;
}

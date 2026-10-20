/* fcc2 Tier-1 regression: GENERAL constant-multiply lowering.  A non-power-of-2
 * constant multiply (x*3, x*5, x*6, and the struct-array index stride) must
 * lower to a shift-add sequence equivalent to the old _fcc_mul16 libcall, NOT
 * change the value.  A power-of-2 multiply (x*8) stays ASLxn (control).  Values
 * vs a clang host reference; total masked to 8 bits (exit code is 8-bit).
 *   tbl[i].val sum (stride-12 array-of-struct index): 1+2+3+4+5 = 15
 *   times(3) = 3*3 + 3*5 + 3*6 = 3*14                = 42  -> 57
 *   9*8 (pow2 control)                               = 72  -> 129
 */
struct cell { char tag[10]; int val; };   /* non-power-of-2 stride (10 + int) */
static struct cell tbl[5];

static int times(int x)
{
    return x * 3 + x * 5 + x * 6;          /* explicit non-pow2 const muls */
}

int main(void)
{
    int i, t = 0;
    for (i = 0; i < 5; i++) tbl[i].val = i + 1;   /* arr[i] lvalue: stride multiply */
    for (i = 0; i < 5; i++) t = t + tbl[i].val;   /* arr[i] rvalue: stride multiply */
    t = t + times(3);                              /* explicit x*const path */
    t = t + 9 * 8;                                 /* pow2 control (ASL x3) */
    return t & 0xFF;                               /* 129 */
}

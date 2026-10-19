/* fcc2 P1.3-inc2 regression: an indirect (function-pointer) call must
 * DISQUALIFY the caller from DP-IMG local promotion.  The indirect call lowers
 * to a tokenless computed-RTS trampoline (no JSR/JSL/FARCALL), so an eligibility
 * scan that only looks for those mnemonics would wrongly deem the caller
 * call-clean and promote its hot loop counter / accumulator into $C0..$DF — the
 * very slots the indirectly-called callee also promotes and leaves dirty.
 *
 * ip_callee promotes its own a/j into $C0..$DF and returns a = 2*x.  If main is
 * (wrongly) promoted, its `i`/`sum` collide with ip_callee's slots and `i` is
 * corrupted across the call, so the loop runs the wrong number of times and the
 * result is not 42.  Correct codegen (caller NOT promoted) returns 3*14 = 42. */
typedef int (*cb_t)(int);

int ip_callee(int x)
{
    int a = 0, j;
    for (j = 0; j < x; j++) a += 2;   /* a -> img, j -> img; a == 2*x */
    return a;
}

int main(void)
{
    cb_t f = ip_callee;
    int sum = 0, i;
    for (i = 0; i < 3; i++)
        sum = sum + f(7);             /* indirect call; ip_callee(7) == 14 */
    return sum;                        /* 3 * 14 == 42 iff `i` survived */
}

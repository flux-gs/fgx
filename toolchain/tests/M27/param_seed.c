/* fcc2 P1.3-inc2 regression: a loop-hot int/char scalar PARAM is promoted to a
 * DP-IMG slot AND seeded from its stack home at function entry.  Exercises the
 * IR_SEED_MARK -> ir_emit_param_seeds path (LDA <param>,S / STA _fcc_img{k}),
 * which otherwise has no oracle coverage (no other fixture has a loop-hot scalar
 * param).  If the seed loads the wrong offset, the result is not 42.
 *
 * n is read 3x (loop cond + loop body + return), 2 of them inside the loop, so
 * it is loop-hot and >= the promotion threshold -> promoted + seeded.
 * p_sum(6): loop adds n six times -> s = 36; return s + n = 42. */
int p_sum(int n)
{
    int s = 0, i;
    for (i = 0; i < n; i++)
        s = s + n;
    return s + n;
}

int main(void)
{
    return p_sum(6);   /* 6*6 + 6 == 42 */
}

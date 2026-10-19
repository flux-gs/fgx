/* T5-C C5 side-find: arr[i]++ / arr[i]-- in STATEMENT position was an
 * artificial reject ("expected '='") while the identical shape compiled in
 * expression position (N_ARR_POSTINC).  The statement subscript arm now
 * reuses the expression node (yield discarded); same scope as the
 * expression arm: single subscript, int/char arrays.  Bit us live: the
 * C printf engine's %g carry loop (__lc_pf_dig[i]++).  10+16+8+8 = 42. */
int  w[3];
char b[3];

int main(void)
{
    int i = 1;
    int ok = 10;

    w[1] = 4;
    w[i]++;                 /* int array, variable index */
    b[2] = 9;
    b[2]--;                 /* char array, constant index */
    if (w[1] == 5) ok += 16;
    if (b[2] == 8) ok += 8;
    if (i == 1)    ok += 8;    /* later local read intact */
    return ok;
}

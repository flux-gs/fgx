/* fcc2 P1.4 (B1c) regression: the *p++ / *p-- WALK IDIOM on a promoted pointer.
 * The deref must read the OLD pointer (before the bump) via LDA [_fcc_img{k}],
 * with the bump applied AFTER.  A stride-1 char/void ptr uses an A-preserving
 * INC/DEC of the offset slot (char mask LAST so N/Z reflect the value); a
 * stride>1 int ptr uses PHA / add-or-sub stride to the slot / PLA so the deref
 * result in A survives the bump.  All pointers here are loop-hot PARAMS ->
 * param-promoted to a contiguous img pair + 4-byte seeded at entry.  Covers
 * every stride x direction combo of the promoted path:
 *   sum_fwd : char* *p++  (stride-1 INC) -> 1+2+3+4  = 10
 *   sum_bwd : char* *p--  (stride-1 DEC) -> 7+6+5    = 18
 *   isum_bwd: int*  *p--  (stride-2 DEC) -> 30+20+10 = 60
 *   total                                           = 88  (<=255: exit code is 8-bit)
 * (int* *p++ / stride-2 INC is covered by tests/M6/starinc_r.) */
static char fwd[5];
static char bwd[3];
static int  v[3];

static int sum_fwd(const char *p)
{
    int s = 0, c;
    while ((c = *p++) != 0)   /* *p++ rvalue: deref old p, then p++ (stride 1) */
        s = s + c;
    return s;
}

static int sum_bwd(const char *p, int n)
{
    int s = 0;
    while (n > 0) {
        s = s + *p--;         /* *p-- rvalue: deref old p, then p-- (stride 1) */
        n = n - 1;
    }
    return s;
}

static int isum_bwd(const int *p, int n)
{
    int s = 0;
    while (n > 0) {
        s = s + *p--;         /* *p-- on int*: deref old p, then p -= 2 (stride 2) */
        n = n - 1;
    }
    return s;
}

int main(void)
{
    fwd[0] = 1; fwd[1] = 2; fwd[2] = 3; fwd[3] = 4; fwd[4] = 0;
    bwd[0] = 5; bwd[1] = 6; bwd[2] = 7;
    v[0] = 10; v[1] = 20; v[2] = 30;
    return sum_fwd(fwd) + sum_bwd(&bwd[2], 3) + isum_bwd(&v[2], 3);   /* 10+18+60 = 88 */
}

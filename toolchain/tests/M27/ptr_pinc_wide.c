/* fcc2 Track-2 lever-3 regression: the *p++ WALK IDIOM must read the FULL
 * pointee width for long* / float* / pointer-to-pointer (these never promote,
 * so they exercise the un-promoted lowering emit_deref_postinc_local_lower).
 *
 * Before the fix, *p++ on these wide pointees emitted a single 16-bit
 * `LDA [_fcc_ptr]` and tagged the result LT_INT — truncating a long/float to
 * its low word and dropping the bank byte of a pointer pointee.  Each sub-case
 * below is built so a truncated read yields a WRONG total:
 *
 *   sum_long : long*  values 0x10000/0x20000/0x30000 (low word 0) -> a 16-bit
 *              read gives 0; faithful read >>16 = 1+2+3            = 6
 *   sum_float: float* values 2.0/4.0 (IEEE-754 low word 0)        -> 16-bit
 *              read gives 0.0; faithful read (int)f = 2+4          = 6
 *   sum_pp   : int**  -> *p++ yields a 4-byte pointer; the fix routes it
 *              through the faithful ISPTR path (emit_load_ptr_value_via_
 *              fcc_ptr).  In single-bank FGX1 the old path's wrong bank
 *              (p's own bank) coincides with the pointee bank, so this
 *              sub-case = 10+20+30 = 60 both ways — an ISPTR-path guard
 *              (the genuine cross-bank ptr-to-ptr case is a separate
 *              ticket).  The long+float cases are the truncation detectors.
 *   total = 6 + 6 + 60                                            = 72
 * (<=255: exit code is 8-bit.)  Host clang reference = 72.
 * Buggy fcc (pre-fix) returns 60 (long+float truncate to 0). */
static long  la[3];
static float fa[2];
static int   x, y, z;
static int  *pa[3];

static int sum_long(const long *p, int n)
{
    long s = 0;
    while (n > 0) {
        s = s + *p++;            /* full 32-bit long deref */
        n = n - 1;
    }
    return (int)(s >> 16);
}

static int sum_float(const float *p, int n)
{
    int s = 0;
    while (n > 0) {
        float f = *p++;          /* full 32-bit float deref */
        s = s + (int)f;
        n = n - 1;
    }
    return s;
}

static int sum_pp(int **p, int n)
{
    int s = 0;
    while (n > 0) {
        int *q = *p++;           /* full 4-byte pointer deref (offset + bank) */
        s = s + *q;
        n = n - 1;
    }
    return s;
}

int main(void)
{
    la[0] = 0x00010000L; la[1] = 0x00020000L; la[2] = 0x00030000L;
    fa[0] = 2.0f; fa[1] = 4.0f;
    x = 10; y = 20; z = 30;
    pa[0] = &x; pa[1] = &y; pa[2] = &z;
    return sum_long(la, 3) + sum_float(fa, 2) + sum_pp(pa, 3);   /* 6 + 6 + 60 = 72 */
}

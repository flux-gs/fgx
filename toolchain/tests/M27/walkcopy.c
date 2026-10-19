/* fcc2 walk-store push-elision (B1c-2a-step-2): `*d++ = *s++` walk-WRITE on a
 * promoted dest pointer should collapse to STA [_fcc_img{k}] + bump (no 4-byte
 * address push across the RHS eval).  Both d (walk-WRITE) and s (walk-READ) are
 * loop-hot params -> promoted to img pairs.
 *   ccopy: char* `*d++ = *s++`  (stride-1 byte store)
 *   icopy: int*  `*d++ = *s++`  (stride-2 int store)
 * Verifies the copies land correctly: 'A'+'B' + 3+5 = 65+66+3+5 = 139.
 * Host clang reference = 139. */
static char csrc[4];
static char cdst[4];
static int  isrc[4];
static int  idst[4];

static void ccopy(char *d, const char *s)
{
    while (*s) *d++ = *s++;     /* char walk-write: store at old d, then d++ */
    *d = 0;
}

static void icopy(int *d, const int *s, int n)
{
    while (n > 0) { *d++ = *s++; n = n - 1; }   /* int walk-write: stride-2 store */
}

int main(void)
{
    csrc[0] = 'A'; csrc[1] = 'B'; csrc[2] = 0;
    ccopy(cdst, csrc);
    isrc[0] = 3; isrc[1] = 5;
    icopy(idst, isrc, 2);
    return cdst[0] + cdst[1] + idst[0] + idst[1];   /* 65+66+3+5 = 139 */
}

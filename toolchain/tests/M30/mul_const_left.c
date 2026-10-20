/* apple/fgx#453: a constant multiplier reaches the inline constant-multiply
 * lowering on EITHER side of `*', and behind parentheses, a cast or a macro --
 * not only as a bare literal on the right.  `SB_FREE + 4 * i' is ufs_sb.c's
 * own shape, and it was a 16-pass _fcc_mul16 call per field decoded.  A
 * multi-dimensional row stride (256, 10) takes the same lowering.
 *
 * The .expected.s is what pins the lowering (no JSR _fcc_mul16 for the
 * inlineable constants); the exit code pins the values, computed on the host
 * with 16- and 32-bit wraparound.  Exit 42, or the number of the first check
 * that failed. */
#define SB_FREE 16
#define FOUR    (4)

static int iv(int x) { return x; }              /* keeps a value out of */
static unsigned uv(unsigned x) { return x; }    /*   the constant folder */
static long lv(long x) { return x; }

static char row256[3][256];
static char row10[4][10];

int main(void)
{
    int i = iv(7), j = iv(-3), r = iv(2);
    unsigned u = uv(40000);
    char c = (char)iv(9);
    long l = lv(100000L);

    if (4 * i != 28) return 1;
    if (2 * j != -6) return 2;
    if ((4) * i != 28) return 3;
    if (i * (4) != 28) return 4;
    if ((int)4 * i != 28) return 5;
    if (SB_FREE + 4 * i != 44) return 6;
    if (FOUR * i != 28) return 7;
    if (10 * i != 70) return 8;                 /* shift-add, constant left */
    if (12345 * i != 20879) return 9;           /* not inlineable: libcall */
    if (4 * i * j != -84) return 10;            /* (4*i)*j, as parsed */
    if (-4 * i != -28) return 11;
    if (3u * u != 54464u) return 12;
    if (4 * c != 36) return 13;
    if (sizeof(long) * i != 28) return 14;
    if (4 * l != 400000L) return 15;            /* long, a shift */
    if (l * (8) != 800000L) return 16;
    if (i * 4 * j != -84) return 17;            /* literal then `*': general path */

    row256[r][5] = 11;                          /* variable row: stride 256 */
    row10[r + 1][i] = 12;                       /* variable row: stride 10 */
    if (row256[2][5] != 11) return 18;
    if (row10[3][7] != 12) return 19;
    row256[1][i] = 13;
    row10[1][i] = 14;
    r = iv(1);
    if (row256[r][7] != 13) return 20;
    if (row10[r][7] != 14) return 21;
    return 42;
}

/* fcc2 isel Phase 1: load-op fold NEGATIVES — each binop here MUST NOT fold (a
 * gate forbids it), so each still emits `STA _fcc_tmp_b`.  Verified by grep +
 * the oracle value.  clang reference: 47.
 *   - `x + cv` : char global RHS leaf  -> gate 2 (mask), stays unfolded
 *   - `x + (y*gi)` : complex (non-leaf) RHS -> gate 1, stays unfolded
 *   - `x + p` : param RHS leaf          -> gate 3 (kind != LK_LOCAL), unfolded */
char cv = 4;
int gi = 7;

static int viacomplex(int x, int y) { return x + (y * gi); }   /* complex RHS */
static int viaparam(int p)          { int x = 5; return x + p; } /* param RHS leaf */

int main(void)
{
    int x = 30;
    int r = x + cv;             /* char leaf -> NOT folded */
    r = r + viacomplex(1, 1);   /* +8  (call RHS -> NOT folded) */
    r = r + viaparam(0);        /* +5  (call RHS -> NOT folded) */
    return r;                   /* 30+4 + 8 + 5 = 47 */
}

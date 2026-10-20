/* M39 (frotz port): read-modify-write through a COMPUTED pointer.
 * `*(b - 1) ^= c` is frotz mem_diff's compound store; `(*(fp - n))--`
 * and `value = --(*(fp - n))` are z_dec / z_dec_chk's Z-machine local-
 * variable bumps.  Old fcc died "expected '='" on the compound store and
 * "(lvalue)++/-- requires a '*ptr' lvalue" on both incdec forms.  The
 * named-pointer forms `(*sp)--` / `--(*sp)` were always fine and are
 * pinned here so the general arm can never steal them. */

typedef unsigned short zword;

static zword s[8];
static zword *sp = s;
static zword *fp;
static unsigned char buf[8];

int main(void)
{
    zword n = 2;
    zword v;
    unsigned char c = 0x55;
    unsigned char *b = buf + 3;

    fp = s + 4;

    s[2] = 7;                   /* the cell *(fp - 2) names */
    (*(fp - n))--;              /* 7 -> 6: postfix statement */
    v = --(*(fp - n));          /* 6 -> 5, prefix yields the NEW value */
    if (v != 5 || s[2] != 5) return 1;

    buf[2] = 0xF0;
    *(b - 1) ^= c;              /* 0xF0 ^ 0x55 = 0xA5 */
    if (buf[2] != 0xA5) return 2;
    *(b - 1) += 3;              /* 0xA5 + 3 = 0xA8 */
    if (buf[2] != 0xA8) return 3;

    s[0] = 9;
    (*sp)--;                    /* named pointer: the old fast path */
    v = --(*sp);
    if (v != 7 || s[0] != 7) return 4;

    return 42;
}

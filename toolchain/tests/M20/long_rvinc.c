/* M20: pre/post ++/-- of a LOCAL long used as an RVALUE (value consumed by
 * the enclosing relational) must carry/borrow into the high word.  The
 * 16-bit-only low-word path made `--blocks` wrap 0 -> 0x0000FFFF (65535 >= 0)
 * instead of -1: the 2.11BSD tar(1) `while (--blocks >= 0) putempty()`
 * zero-block write runaway (toolchain v1.10.0, fixed v1.10.1).  The `count<50`
 * guards keep a regression bounded instead of hanging the harness. */
int main(void)
{
    long blocks;
    int count, total;

    total = 0;
    blocks = 3;                       /* prefix: --blocks as rvalue */
    count = 0;
    while (--blocks >= 0 && count < 50)
        count++;
    total = total + count;            /* +3 (blocks 2,1,0 then -1 stops) */

    blocks = 0;                       /* postfix: blocks-- as rvalue, into negative */
    count = 0;
    while (blocks-- >= 0 && count < 50)
        count++;
    total = total + count * 10;       /* +10 (0>=0 true, then -1 stops) */

    return total;                     /* 13 when carry/borrow is correct */
}

/* fcc2 isel Phase 1: RHS-leaf load-op fold for LOCAL (n,S) leaf operands across
 * all five kinds.  b..f are each accessed once -> stay n,S leaves (not promoted)
 * -> fold to `[CLC|SEC] <op> slot,S` with the -2 PUSH_A fixup.  clang ref: 12. */
int main(void)
{
    int a = 8, b = 5, c = 3, d = 12, e = 10, f = 6;
    int r = a + b;   /* 13   CLC/ADC b,S */
    r = r - c;       /* 10   SEC/SBC c,S */
    r = r & d;       /*  8   AND d,S */
    r = r | e;       /* 10   ORA e,S */
    r = r ^ f;       /* 12   EOR f,S */
    return r;        /* 12 */
}

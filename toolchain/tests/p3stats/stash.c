/* fcc2 Phase-3 inc-0 L3 fixture.
 *  - a + (b * g): the RHS (b*g) is a complex sub-expression -> STASH_RHS_INT
 *    that is NOT a foldable leaf  -> L3_complex.
 *  - a + c with c a CHAR global: the RHS is a single leaf load that ir_select
 *    rejected (char gate) -> a surviving foldable stash -> L3_leafmiss. */
int  g;
char c;
int f(int a, int b) {
    int x = a + (b * g);
    int y = a + c;
    return x + y;
}

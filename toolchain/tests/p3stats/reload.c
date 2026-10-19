/* fcc2 Phase-3 inc-0 L1/L2 fixture (hand-checkable):
 *   x = a + 1;   STORE x
 *   y = x + 2;   LOAD x   -> L1 within-BB (store->reload, no barrier/redef)
 *   g = x;       LOAD x   -> L2 within-BB (load->reload of the same value)
 *   return y + g (LOAD g, a global, after STORE g) -> L1 within-BB (global). */
int g;
int f(int a) {
    int x = a + 1;
    int y = x + 2;
    g = x;
    return y + g;
}

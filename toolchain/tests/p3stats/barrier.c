/* fcc2 Phase-3 inc-0 L5 fixture: a deref barrier sits between the producer of x
 * and its reload, so the reload is cross-barrier (L1_xbar_deref) and the deref
 * is counted once as a coverage opportunity (L5_sand_deref). */
int f(int *p, int a) {
    int x = a + a;   /* STORE x (a+a clobbers A, not peephole-forwardable) */
    int z = *p;      /* DEREF barrier (clobbers A, SP-dependent) */
    return x + z;    /* LOAD x across the deref -> L1_xbar_deref + L5_sand_deref */
}

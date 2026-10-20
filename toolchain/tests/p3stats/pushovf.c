/* fcc2 Phase-3 inc-0 L4 fixture: a deep expression tree that keeps >2 partial
 * results live simultaneously, forcing PUSH_A past X+Y -> real PHA/PLA survive
 * ir_alloc_bb as IR_PUSH_A (L4_ovf). */
int f(int a, int b, int c, int d) {
    return (a + b) * ((c + d) + (a * b)) + (c * d);
}

/* expect: need an arithmetic operand */
/* K&R A.7.6: "The operands of * and / must have arithmetic type", and by
 * A.7.17 `p *= 2' makes p one of them.  A pointer is not arithmetic. */
int *p;

int f() { p *= 2; return 0; }

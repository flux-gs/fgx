/* expect: apply only to integral operands */
/* K&R A.7.8: for `<<' and `>>' "each operand must be integral".  A float
 * shifted the low word of its bit pattern. */
float fv;
int x;

int f() { x = fv << 1; return 0; }

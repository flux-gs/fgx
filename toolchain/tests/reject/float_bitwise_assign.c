/* expect: apply only to integral operands */
/* K&R A.7.17: `E1 op= E2' is `E1 = E1 op (E2)', and A.7.13: `|' "applies only
 * to integral operands".  A float took a 16-bit OR against a stale temporary. */
float fv;

int f() { fv |= 1; return 0; }

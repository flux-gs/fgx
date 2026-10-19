/* expect: switch expression must have integral type */
/* K&R A.9.4: the switch expression "must have integral type".  A float
 * compared the low word of its bit pattern against the case constants. */
float fv;

int f() { switch (fv) { case 1: return 1; } return 0; }

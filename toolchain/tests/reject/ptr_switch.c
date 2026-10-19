/* expect: switch expression must have integral type */
/* K&R A.9.4: the switch expression "must have integral type".  A pointer
 * compared its offset against the case constants and ignored its bank. */
char *p;

int f() { switch (p) { case 0: return 1; } return 0; }

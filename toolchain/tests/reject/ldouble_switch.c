/* expect: switch expression must have integral type */
/* long double, increment 2 of apple/fgx#447: a switch is refused, not
 * miscompiled. */
long double a;
f() { switch (a) { case 1: return 1; } return 0; }

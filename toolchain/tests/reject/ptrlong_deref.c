/* expect: a pointer converts to a long only by a cast */
/* apple/fgx#543, K&R A.6.6: pointer-to-integer conversions "must be specified
 * by an explicit type-conversion operator, or cast".  Form: through a pointer. */
char b[2]; long g; int f() { long *lp = &g; char *p = b; *lp = p; return 0; }

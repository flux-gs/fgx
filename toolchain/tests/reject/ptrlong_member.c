/* expect: a pointer converts to a long only by a cast */
/* apple/fgx#543, K&R A.6.6: pointer-to-integer conversions "must be specified
 * by an explicit type-conversion operator, or cast".  Form: member through a pointer. */
struct s { long m; } v; char b[2]; int f() { struct s *sp = &v; char *p = b; sp->m = p; return 0; }

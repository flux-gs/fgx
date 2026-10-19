/* expect: a pointer converts to a long only by a cast */
/* apple/fgx#543, K&R A.6.6: pointer-to-integer conversions "must be specified
 * by an explicit type-conversion operator, or cast".  Form: array field through a pointer. */
struct s { long a[2]; }; char b[2]; int f(sp) struct s *sp; { char *p = b; sp->a[1] = p; return 0; }

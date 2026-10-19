/* expect: a pointer converts to a long only by a cast */
/* apple/fgx#543, K&R A.6.6: pointer-to-integer conversions "must be specified
 * by an explicit type-conversion operator, or cast".  Form: member chain. */
struct t { long m; }; struct s { struct t *q; }; char b[2]; int f(sp) struct s *sp; { char *p = b; sp->q->m = p; return 0; }

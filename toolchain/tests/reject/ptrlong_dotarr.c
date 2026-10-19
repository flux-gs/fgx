/* expect: a pointer converts to a long only by a cast */
/* apple/fgx#543, K&R A.6.6: pointer-to-integer conversions "must be specified
 * by an explicit type-conversion operator, or cast".  Form: array field of a struct. */
struct s { long a[2]; } v; char b[2]; int f() { char *p = b; v.a[1] = p; return 0; }

/* expect: an array is not a modifiable lvalue */
/* apple/fgx#395.  K&R A.7.3.3: `s.m' is an lvalue only "if the type is not an
 * array type", and A.7.17: the left operand "must be modifiable: it must not
 * be an array".  This compiled to a two-byte store over the member's first
 * element. */
struct sl { int t; int w[4]; };
struct sl obj;
int *q;

int f() { obj.w = q; return 0; }

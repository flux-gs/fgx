/* expect: only `=' is defined on a whole struct or union member */
/* apple/fgx#393.  Through a pointer (S_COMPOUND_MEMBER) -- a fourth arm, and
 * K&R A.7.3.3 makes `p->u' the same object as `(*p).u', so it answers the
 * same way. */
struct in { int n; char s[4]; };
struct sl { int t; struct in u; };
struct sl *p;

int f() { p->u |= 2; return 0; }

/* expect: only `=' is defined on a whole struct or union member */
/* apple/fgx#393.  The fifth arm (S_MEMBER_INCDEC_STMT).  Five spellings
 * reached five different nodes and only one carried any check at all. */
struct in { int n; char s[4]; };
struct sl { int t; struct in u; };
struct sl *p;

int f() { p->u--; return 0; }

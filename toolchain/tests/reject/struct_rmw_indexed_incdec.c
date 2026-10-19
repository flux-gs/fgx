/* expect: only `=' is defined on a whole struct or union member */
/* apple/fgx#393.  The array-element base's ++/-- arm (S_FIELD_INCDEC_AT),
 * the twin of struct_rmw_indexed_compound.c. */
struct in { int n; char s[4]; };
struct sl { int t; struct in u; };
struct sl vs[4];

int f() { vs[0].u++; return 0; }

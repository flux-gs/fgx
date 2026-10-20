/* expect: only `=' is defined on a whole struct or union member */
/* apple/fgx#393.  K&R A.7.17: `E1 op= E2' is `E1 = E1 op (E2)', and A.7.7
 * gives `+' no meaning on a structure.  THE ARRAY-ELEMENT base, which is the
 * arm that emitted a silent 16-bit read-modify-write over the member's first
 * word (S_FIELD_COMPOUND_AT). */
struct in { int n; char s[4]; };
struct sl { int t; struct in u; };
struct sl vs[4];

int f() { vs[0].u += 1; return 0; }

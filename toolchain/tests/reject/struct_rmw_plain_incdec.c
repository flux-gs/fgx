/* expect: only `=' is defined on a whole struct or union member */
/* apple/fgx#393.  K&R A.7.3.4: `++' increments the operand "by 1", and it
 * defers to A.7.7, which gives `+' no meaning on a structure.  This is the
 * PLAIN base, reaching the lvalue-suffix chain (S_LV_INCDEC). */
struct in { int n; char s[4]; };
struct sl { int t; struct in u; };
struct sl obj;

int f() { obj.u++; return 0; }

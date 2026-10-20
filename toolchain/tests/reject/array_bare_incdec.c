/* expect: an array is not a modifiable lvalue */
/* apple/fgx#395.  K&R A.7.1: an array's conversion to a pointer "does not take
 * place if the expression is in the operand of ... ++, --", so `a++' names the
 * ARRAY, and A.7.17 (which A.7.3.4 defers to) forbids it.  A LOCAL array took
 * the pointer-stride path and advanced its own first element. */
int f() { int la[4]; la++; return 0; }

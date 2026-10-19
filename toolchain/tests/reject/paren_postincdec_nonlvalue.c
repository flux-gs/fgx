/* expect: '++'/'--' needs a modifiable lvalue */
/* apple/fgx#448.  `(E)++' is `E++' only when E is ONE postfix expression
 * (K&R A.7.2, A.7.3.4).  `(a + b)' is not an lvalue, so the grouping ')' must
 * not be spliced -- that would silently compile `a + b++'. */
int a, b, x;

int f() { x = (a + b)++; return x; }

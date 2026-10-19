/* absfnptr.c — abstract fn-ptr PROTOTYPE extern `int f(int (*)(int), int)`.
 * fcc previously required a parameter name inside the fn-ptr declarator and
 * rejected the abstract (unnamed) form with "expected parameter name"; a
 * prototype only needs the type.  The matching named-param DEFINITION shares the
 * prototype ABI, so the call passes its args in order.  -> 42. */
extern int apply(int (*)(int), int);        /* abstract fn-ptr param */

int dbl(int v) { return v + v; }

int apply(int (*fp)(int), int v) { return fp(v); }

int main(void) { return apply(dbl, 21); }   /* dbl(21) = 42 */

/* expect: double conversion from long long is not implemented yet */
/* long double (apple/fgx#447): a long long converted to a long double, which the soft double has no routine for, is refused. */
long double a;
long long l;
f() { a = l; }

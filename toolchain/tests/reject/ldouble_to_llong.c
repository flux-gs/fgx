/* expect: double conversion to long long is not implemented yet */
/* long double (apple/fgx#447): a long double converted to a long long, which the soft double has no routine for, is refused. */
long double a;
long long l;
f() { l = a; }

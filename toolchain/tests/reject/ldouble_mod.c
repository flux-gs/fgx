/* expect: '%', '<<' and '>>' apply only to integral operands (K&R A.7.6, A.7.8) */
/* long double (apple/fgx#447): `%' needs integral operands (K&R A.7.6). */
long double a, b;
f() { a = a % b; }

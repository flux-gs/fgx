/* expect: `%=', `<<=' and `>>=' apply only to integral operands (K&R A.7.6, A.7.8) */
/* long double (apple/fgx#447): `<<=' needs an integral operand (K&R A.7.8). */
long double a;
f() { a <<= 1; }

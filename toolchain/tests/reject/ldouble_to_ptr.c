/* expect: a double cannot be converted to a pointer */
/* long double (apple/fgx#447): a long double does not convert to a pointer. */
long double a;
char *f() { return (char *)a; }

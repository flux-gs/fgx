/* A pointer converted to a long BY A CAST keeps all of it: K&R A.6.6, "A
 * pointer may be converted to an integral type large enough to hold it", the
 * mapping fcc's own -- offset in the low word, bank in the high.  The same
 * conversion without the cast is refused (tests/reject/ptrlong_*.c,
 * apple/fgx#543); these are the spellings that stay accepted: assignment,
 * initializer and return, to long and to long long. */
char b[2];
long g;
long long q;

long
f()
{
    char *p = b;
    long l = (long)p;

    g = (long)p;
    q = (long long)p;
    return ((long)p == l ? (long)p : 0L);
}

main()
{
    return (f() != 0 && g == f() && (long)q == g ? 42 : 7);
}

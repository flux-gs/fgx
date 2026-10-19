/* A CALL THAT COMES BEFORE THIS TU'S OWN DEFINITION OF A NAME THE SIDECAR ALSO
 * NAMES.  sigsdef covers the definition coming first; this is the other order,
 * and it is 2.11BSD su(1)'s: su calls its own setenv(ename, eval, buf) above
 * the body, libc's setenv(name, value, rewrite) is in the sidecar, and the
 * third argument went out as a 2-byte int that su's setenv read as a 4-byte
 * pointer -- strcat then ran off through the bank and `su nobody' never
 * returned.
 *
 * The call binds to the definition below, never to libc's (the linker's
 * strong-over-LIBC rule), so K&R A.7.3.2 governs it: "If the postfix
 * expression consists of an identifier for which no declaration exists in the
 * current scope, the identifier is implicitly declared as if the declaration
 * extern int identifier(); had been given", with default argument promotion
 * for an old-style declaration.  `dst' is an array, so it goes out as the
 * 4-byte pointer the definition reads.
 *
 * sigsown.sigs gives `fill' an int first parameter.  The arguments are pushed
 * right to left, so a 2-byte `d' leaves the callee reading a's offset as d's
 * bank and every later parameter shifted; the exit is 42 only if all three
 * bytes arrive, and 7 otherwise.
 */
char dst[8];

main()
{
    dst[0] = 'x';
    dst[1] = 0;
    return (fill(dst, "ab", "c"));
}

fill(d, a, b)
    char *d, *a, *b;
{
    if (d[0] == 'x' && a[1] == 'b' && b[0] == 'c')
        return (42);
    return (7);
}

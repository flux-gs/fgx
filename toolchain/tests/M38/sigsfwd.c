/* A LINT VARARGS FUNCTION'S TRAILING ARGUMENTS ARE NOT NARROWED.  2.11BSD
 * fsck's pwarn(s, a1, ..., a8) is marked VARARGS1, defined with int
 * parameters, and hands them straight to printf, so a `%ld' or `%s' argument
 * has to reach it at its own width and leave it the same way.  K&R A.7.3.2:
 * "trailing arguments beyond the explicitly typed parameters suffer default
 * argument promotion".  fcc converted them to the int parameters, through the
 * --sigs entry and through the definition alike, so a long went out as its
 * low word and a pointer without its bank, and fsck printed `Tle system is
 * clean' and `798033096 files' (apple/fgx#549).
 *
 * fwd is called before its definition, so the call sees sigsfwd.sigs's entry
 * (four int parameters, `v0'); fwdb is defined first, so its call sees the
 * definition.  Both forward to chk, declared `chk()' as printf is, which
 * reassembles the long and the pointer.
 *
 * nar carries no marker and is the control: a fixed-arity call still
 * converts its arguments to the parameters, so `b' arrives as 5 although a
 * long went in ahead of it.  df's fsbtoblk(long, int, int) called with a long
 * block size, and tcsh's qsort with a size_t count, depend on that.
 *
 * Exit 42 only if all three hold.
 */
char str[] = "abc";
int chk();

/* VARARGS */
fwdb(a1, a2, a3, a4)
    int a1, a2, a3, a4;
{
    return (chk(a1, a2, a3, a4));
}

nar(a, b)
    int a, b;
{
    return (b);
}

main()
{
    long n = 0x12345678L;

    if (nar(n, 5) != 5)
        return (6);
    if (fwd(n, str) != 42)
        return (7);
    return (fwdb(n, str));
}

/* VARARGS */
fwd(a1, a2, a3, a4)
    int a1, a2, a3, a4;
{
    return (chk(a1, a2, a3, a4));
}

chk(n, p)
    long n;
    char *p;
{
    return (n == 0x12345678L && p == str ? 42 : 7);
}

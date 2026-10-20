/* Prefix ++/-- statements on `*' of an expression, not just `*name'.  K&R
 * A.7.4.1: the operand "must be an lvalue"; A.7.4.3: unary * "is an lvalue if
 * the operand is a pointer to an object of arithmetic, structure, union, or
 * pointer type".  2.11BSD's ecvt.c carries `++*--p1;' in its rounding loop.
 * A failing check returns its number; all passing returns 42. */
char buf[4] = { '1', '9', '9', 0 };

int
main()
{
    char *p1 = &buf[3];

    ++*--p1;
    if (buf[2] != ':' || p1 != &buf[2]) return 1;
    --(*--p1);
    if (buf[1] != '8' || p1 != &buf[1]) return 2;
    ++*(p1 - 1);
    if (buf[0] != '2' || p1 != &buf[1]) return 3;
    return 42;
}

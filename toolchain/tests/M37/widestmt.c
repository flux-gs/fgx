/* Statement-level op=, ++/-- and a discarded value on an element wider than
 * an int, reached through `*': a long array (`*ga += ...'), a long pointer
 * (`*lp -= ...', `(*lp)++'), a pointer to a pointer (`(*cpp)++') and a value
 * thrown away (`*lp++;', which steps the pointer).  K&R A.7.4.3 makes `*E' an
 * lvalue for a pointer to any arithmetic or pointer object, and A.7.17 /
 * A.7.3.4 give it op= and ++.  Every long is chosen with a nonzero high word,
 * so a 16-bit store cannot fake a pass.  Exits 42 iff all six land. */
long ga[2];
long gl[2];
char buf[4];
char *cp;

int
main()
{
    long *lp;
    char **cpp;
    long a, b;
    int ok;

    ok = 0;
    ga[0] = 0x10000L;
    a = 0x30005L;
    b = 0x10002L;
    *ga += a - b;                       /* 0x10000 + 0x20003 = 0x30003 */
    if (ga[0] == 0x30003L)
        ok += 7;

    gl[0] = 0x50000L;
    gl[1] = 0x70001L;
    lp = gl;
    *lp -= 0x10001L;                    /* 0x3FFFF: a borrow across words */
    if (gl[0] == 0x3FFFFL)
        ok += 7;
    (*lp)++;                            /* 0x40000: a carry across words */
    if (gl[0] == 0x40000L)
        ok += 7;
    *lp++;
    if (lp == &gl[1] && *lp == 0x70001L)
        ok += 7;

    cp = buf;
    buf[1] = 'Z';
    cpp = &cp;
    (*cpp)++;
    if (*cp == 'Z')
        ok += 7;
    --(*lp);
    if (gl[1] == 0x70000L)
        ok += 7;
    return ok;
}

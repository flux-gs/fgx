/* K&R varargs ABI (right-to-left args).  A function forward-declared empty-paren
 * (variadic — no arg-count check) then DEFINED with more params than the call
 * passes.  The callee must read param0/param1 from the shallow slots the caller
 * actually pushed.  Left-to-right push put param0 in the wrong DEEP slot (the
 * elvis msg() 28-byte gap).  Returns 42 iff param0==42 and param1==99. */
int knr();

int
main()
{
    /* knr is the empty-paren forward decl here (variadic); called with 2 args
     * though DEFINED below with 8. */
    return knr(42, 99);
}

int
knr(a, b, c, d, e, f, g, h)
    int a, b, c, d, e, f, g, h;
{
    if (a == 42 && b == 99)
        return 42;
    return 1;
}

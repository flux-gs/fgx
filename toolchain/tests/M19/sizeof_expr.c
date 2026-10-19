/* K&R A.7.4.8: "The operand is either an expression, which is not
 * evaluated, or a parenthesized type name."  fcc recognised a fixed set of
 * operand shapes -- a name, a subscript, a member chain, a deref, a string --
 * and refused anything with an operator in it: `sizeof (i + 1)' died
 * "expected ')'".
 *
 * Each expression's size is its TYPE's, so the usual conversions show: a
 * char operand of `+' is promoted, a conditional takes its common type
 * (A.7.16), and a shift keeps its left operand's type (A.7.8).  And "not
 * evaluated" is checked, not assumed: `sizeof (i++)' must leave i alone.
 * Exits 42 iff all hold. */
int
main()
{
    int i = 5;
    long l = 7L;
    char c = 'x';
    char *p = &c;
    int ok = 0;

    if (sizeof (i + 1) == 2 && sizeof (l + 1) == 4 && sizeof (c + c) == 2)
        ok += 10;                   /* char promotes to int (A.6.1) */
    if (sizeof (p + 1) == 4 && sizeof (-c) == 2 && sizeof (!l) == 2)
        ok += 10;
    if (sizeof (i ? l : i) == 4 && sizeof (i << 1L) == 2)
        ok += 11;                   /* A.7.16 common type; A.7.8 left type */
    if (sizeof (i++) == 2 && i == 5)
        ok += 11;                   /* the operand is not evaluated */
    return ok;
}

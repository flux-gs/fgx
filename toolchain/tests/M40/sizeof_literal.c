/* sizeof a constant, bare or parenthesized.  K&R A.7.4.8: "The operand is
 * either an expression, which is not evaluated, or a parenthesized type
 * name", and a constant is a primary expression (A.7.1), so it needs no
 * parentheses.  Its size is its type's: int or long by A.2.5.1's ladder, int
 * for a character constant (2.3: "A character constant is an integer"), and
 * double for an unsuffixed floating constant (A.2.5.3).  A failing check
 * returns its number; all passing returns 42. */
int
main()
{
    if (sizeof 5 != sizeof(int) || sizeof(5) != sizeof(int)) return 1;
    if (sizeof 70000 != sizeof(long) || sizeof(70000) != sizeof(long)) return 2;
    if (sizeof 'a' != sizeof(int) || sizeof('a') != sizeof(int)) return 3;
    if (sizeof 1.5 != sizeof(double) || sizeof(1.5f) != sizeof(float)) return 4;
    return 42;
}

/* paren_lvalue_store: assignment to a PARENTHESIZED member lvalue `(p->m)=rhs`.
 * K&R A.7.2 (a parenthesized expression is a primary preserving lvalue-ness) +
 * A.7.17 (the LHS is any modifiable lvalue; the assignment yields the stored
 * value).  The 2.11BSD Bourne shell hits this via macro expansion: `input` ==
 * `(standin->fdes)`, so `(input=rhs)` becomes `((standin->fdes)=rhs)`.  -> 42. */
struct fb { int fdes; int x; };
struct fb  box;
struct fb *standin;
int rhs_val() { return 42; }

int
main()
{
    int r;
    standin = &box;
    r = ((standin->fdes) = rhs_val());   /* store yields the value */
    return r;                            /* 42 */
}

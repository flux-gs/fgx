/* A void call as a NON-FINAL operand of the comma operator, nested in an
 * expression: `v = (vsrm(v[p]), v[p] = e, v)` -- joe va.h's vaset/adel, where
 * adel(x) is vsrm(x) (void).  Legal C (a discarded operand may be void); fcc's
 * void-in-expression check rejected it because build_comma did not relax the
 * check for discarded operands the way a statement-level comma already does.
 * The FINAL operand still keeps the enclosing context.  FGX-only oracle. */
int sink;
void clear(int *p) { *p = 0; }     /* void, used as a discarded comma operand */

int step(int *a)
{
    int r;
    r = (clear(a), *a = 5, *a);    /* void first operand, value is *a == 5 */
    return r;
}

int main(void)
{
    int x = 99;
    int r = 0;
    r += step(&x);                  /* 5, x == 5 */
    if (x == 5) r += 10;            /* 15 */
    /* void operand mid-chain, twice */
    r = (clear(&sink), r += 7, clear(&x), r + 20);  /* 15+7+20 = 42 */
    return r;
}

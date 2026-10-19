/* Store through a deref of a COMPUTED pointer in EXPRESSION context:
 * `(*E) = rhs` / `(*E) op= rhs` as a comma operand.  joe va.h's aLen(v) is
 * `(*((int *)(v) - 1))` and vaadd/vaset store through it inside comma
 * expressions -- a path the statement-level deref-store never reached, so it
 * died "expected ')'".  FGX-only oracle.  Value 42. */
int hdr[4];              /* hdr[1] is the "length" cell aLen points at */

int bump(int *a)        /* a points at hdr[1]; treat like joe's aLen(a) */
{
    int r;
    /* comma expr: store through (*(a)) , then read it back */
    r = ((*(a)) = 10, (*(a)) = (*(a)) + 5, *a);   /* 15 */
    return r;
}

int main(void)
{
    int *p = &hdr[1];
    int r = 0;
    r += bump(p);                       /* 15, and hdr[1] == 15 */
    if (hdr[1] == 15) r += 15;          /* 30 */
    /* compound op= through a computed deref in a comma */
    (void)((*((int *)hdr + 1)) += 2, 0);/* hdr[1] -> 17 */
    if (hdr[1] == 17) r += 12;          /* 42 */
    return r;
}

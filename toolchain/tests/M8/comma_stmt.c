/* comma_stmt: the C comma operator as an expression statement (pcc cgram.y:
 * an expr-statement is `expression ';'` and ',' is the lowest-precedence
 * binary op; the value is discarded).  fcc's fast-path arms handled only a
 * single lvalue-store or call; a top-level ',' now routes the whole statement
 * through build_comma.  Covers call-led, void-operand, member-led, and
 * deref-led forms (tcsh `blkfree(gargv), gargv = 0;`,
 * `hp->Hnext = np->Hnext, hfree(np);`, `*wp++ = c, --i;`).  -> 42. */
struct S { int m; };
int g;

static void
bump(void)                          /* void call used as a comma operand */
{
    g = g + 5;
}

int
main()
{
    struct S s;
    struct S *p;
    int a, b;
    int arr[2];
    int *q;
    p = &s;
    q = arr;
    a = 10, b = 20;                 /* simple: a=10, b=20 */
    bump(), a = a + 2;              /* void-call-led: g=5, a=12 */
    p->m = 3, s.m = s.m + 2;        /* member-led: s.m=3 then 5 */
    *q++ = 8, --b;                  /* deref-led: arr[0]=8, b=19 */
    return a + s.m + arr[0] + (b - 2) + g - 5;  /* 12+5+8+17+5-5 == 42 */
}

/* Prefix ++/-- on a parenthesized member lvalue, in statement and expression
 * position: `++(p->x)` (whole-paren member), `++(p)->x` (paren base), and the
 * `--` twins.  joe screen.h's outatr uses `++(t)->x;`, b.c uses `++(p->line);`.
 * fcc's prefix arms keyed on a bare-IDENT base and died "expected ';'"/"')'".
 * FGX-only oracle.  Value 42. */
struct s { int x; long y; };

int main(void)
{
    struct s sv;
    struct s *p = &sv;
    int r = 0;

    sv.x = 5; sv.y = 10;

    ++(p->x);            /* whole-paren member, stmt -> 6 */
    if (p->x == 6) r += 10;
    ++(p)->x;            /* paren base, stmt -> 7 */
    if (p->x == 7) r += 10;
    ++(p->y);            /* long field whole-paren, stmt -> 11 */
    if (p->y == 11L) r += 10;

    { int v = ++(p)->x;  /* paren base in expr position -> 8 */
      if (v == 8 && p->x == 8) r += 12; }

    return r;            /* 42 */
}

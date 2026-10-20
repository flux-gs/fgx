/* T5-C C2 pin: paren-wrapped lvalue assignment in EXPRESSION position —
 * `(x) += n` / `(x) = v` / `(p) += n` (the shape va_arg expands to).
 * Was an artificial reject: build_assign only matched a bare identifier.
 * clang cross-checked. */
int main(void)
{
    int x = 0, y = 0;
    char buf[4];
    char *p = buf;
    int r;

    r = ((x) += 40);        /* value-yielding compound through the parens */
    (y) = 2;
    (p) += 1;
    if (r == 40 && (p - buf) == 1)
        return x + y;       /* 42 */
    return 1;
}

/* Function-like #define exercise.
 *
 * MAX(a, b) — paren-aware arg parsing, nested expansion, ternary in body.
 * ADD(x, y) — simple two-arg.
 * GETC(fp)  — single-arg; substitutes fp into body that references
 *              other identifiers (fgetc) verbatim.
 * The string literal in fmt has parens AND commas that must NOT be
 * treated as macro-arg separators.
 *
 * Expected exit code: 42.
 */
#define ADD(x, y) ((x) + (y))
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define DOUBLE(n) ((n) * 2)

int main(void)
{
    int x;
    int y;
    x = ADD(20, 21);              /* 41 */
    y = MAX(DOUBLE(20), x);       /* MAX(40, 41) = 41 */
    return ADD(y, 1);             /* 42 */
}

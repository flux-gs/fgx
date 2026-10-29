/* derefparen.c -- `*(q)->p = c' stores THROUGH (q)->p.
 *
 * K&R 2nd ed A.7.2: "A parenthesized expression is a primary expression
 * whose type and value are identical to those of the unadorned
 * expression"; A.7.3 makes `(q)->p' a postfix expression; A.7.4.3: "The
 * unary * operator denotes indirection, and returns the object or function
 * to which its operand points."  So `*(q)->p = c' is `*q->p = c'.  fcc
 * parsed the operand as the assignment `(q)->p = c' and stored c into the
 * POINTER -- 2.11BSD putc's line-buffered arm, `(*(p)->_ptr = (x)) != '\n'',
 * is that shape, and a terminal's stdout lost every character.
 * Also: a parenthesized assignment inside the operand is still an
 * assignment (`*(q->p = buf2) = 'z''), and the value form compares the
 * stored character.  Exit 42. */

struct s { int a; char *p; };
char buf[4], buf2[4];
struct s gs;

int main()
{
    struct s *q;
    int n, r;

    n = 0;
    q = &gs;
    q->p = buf;
    *(q)->p = 'x';                              /* statement form */
    if (buf[0] == 'x' && q->p == buf) n += 2;
    r = ((*(q)->p = 'y') != '\n');              /* putc's value form */
    if (r == 1 && buf[0] == 'y' && q->p == buf) n += 4;
    r = ((*(q)->p = '\n') != '\n');
    if (r == 0 && buf[0] == '\n') n += 8;
    *(q->p = buf2) = 'z';                       /* assignment inside parens */
    if (q->p == buf2 && buf2[0] == 'z') n += 16;
    *(q)->p++ = 'w';                            /* and the post-increment */
    if (buf2[0] == 'w' && q->p == buf2 + 1) n += 12;
    return n == 42 ? 42 : n;
}

/* `return' takes a whole expression, comma operator included: K&R A.9.6
 * "return expression(opt);", the comma being the outermost expression level
 * (A.7.18).  The left operand runs for its side effect, the right one is the
 * value.  Returns 42 when both hold. */
int n;

int bump(s) int *s; { return (*s)++, 40; }

int main()
{
    n = 1;
    return bump(&n) + n;        /* 40 + 2 */
}

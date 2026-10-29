/* A parenthesized operand followed by a comma whose right operand is a void
 * call, as a whole statement: `(x), f();'.  K&R A.7.18 gives the comma
 * expression "the type and value of the right operand", so a void right
 * operand is a void expression -- legal as a statement, where its value is
 * discarded.  Returns 42 when the call ran. */
int g;

void set(v) int v; { g = v; }

int main()
{
    int x;

    x = 1;
    (x), set(42);
    return g;
}

/* An expression statement may begin with a constant or a unary operator:
 * K&R A.9.2 "expression-statement: expression(opt) ;".  A disabled debug macro
 * that expands to a constant leaves exactly `0;'.  Each statement is evaluated
 * and discarded; returns 42 when control reaches the end. */
#define TRACE(x) 0

int main()
{
    int r;

    r = 42;
    TRACE(r);
    1;
    -1;
    ~r;
    !r;
    'c';
    sizeof r;
    return r;
}

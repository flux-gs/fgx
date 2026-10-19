/* M35/P3-3: recursion — per-frame local independence on the hardware stack.
 * Each recursive activation must get its own frame; a local held across a
 * recursive call must survive.  The HW stack is naturally re-entrant (so was
 * the soft stack), so this passes now and must stay green through the flip.
 *
 * Portable C: clang returns 42. */
int
fib(int n)
{
    int a, b;               /* per-frame locals */
    if (n < 2)
        return n;
    a = fib(n - 1);
    b = fib(n - 2);
    return a + b;
}

int
fact(int n)
{
    int acc;                /* local live across the recursive call */
    if (n <= 1)
        return 1;
    acc = n;
    return acc * fact(n - 1);
}

int
main(void)
{
    if (fib(10) != 55)   return 1;
    if (fact(5) != 120)  return 2;
    if (fib(15) != 610)  return 3;   /* deeper recursion, more frames */
    return 42;
}

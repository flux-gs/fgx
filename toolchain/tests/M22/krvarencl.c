/* Right-to-left arg reorder where the arguments reference the ENCLOSING
 * function's params (hardware-stack, g_s_delta-dependent).  The reversal must
 * compensate each enclosing-param read (the u0 snapshot) so the values stay
 * correct, and must preserve arg ORDER (a*100+b*10+c is order-sensitive).
 * relay(2,3) -> mix3(2,3,5) -> 2*100 + 3*10 + 5 = 235.  Returns 42 iff 235. */
int mix3();
int relay();

int
main()
{
    if (relay(2, 3) == 235)
        return 42;
    return 1;
}

int
relay(p, q)
    int p, q;
{
    /* p and q are enclosing params, used as args in a 3-arg call. */
    return mix3(p, q, 5);
}

int
mix3(a, b, c)
    int a, b, c;
{
    return a * 100 + b * 10 + c;
}

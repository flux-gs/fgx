/* Frame layout: scalars below aggregates.  The arrays come first in the
 * declaration list and in a nested block, yet every scalar must be reached
 * as a near `n,S` slot, because fcc places a function's scalars below its
 * aggregates.  The arrays sit past offset 255 and stay correct through
 * their address.  Returns 42. */
struct big { int v[100]; };

int layout(int k)
{
    char buf[300];
    struct big s;
    int a, i;
    long t;
    char *p;
    int *q;

    for (i = 0; i < 300; i++)
        buf[i] = (char)(i & 0x7F);
    for (i = 0; i < 100; i++)
        s.v[i] = i;
    p = buf;
    t = 0;
    {
        int w[130];
        int j;
        for (j = 0; j < 130; j++)
            w[j] = j;
        t = w[129] - s.v[99];          /* 30 */
    }
    q = &a;                            /* keeps a on the stack */
    *q = p[50] - (buf[140] & 0x7F);    /* 50 - 12 = 38 */
    return a + (int)t - 30 + k;        /* 38 + 4 */
}

int main()
{
    return layout(4);
}

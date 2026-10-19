/* M20: long params + long return + mixed-int-long loop. */
long compute(long a, long b, int n)
{
    long s;
    int  i;
    s = 0L;
    for (i = 0; i < n; i = i + 1) s = s + a + b;
    return s;
}
int main(void)
{
    long r;
    r = compute(100000L, 200000L, 1);   /* 300000 */
    r = r - 299958L;                     /* 42 */
    return (int)r;
}

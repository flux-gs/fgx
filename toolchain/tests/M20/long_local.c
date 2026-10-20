/* M20: local long, basic arithmetic, (int) cast on return. */
int main(void)
{
    long a, b, c;
    a = 100000L;
    b = 50000L;
    c = a + b;            /* 150000 */
    c = c - 149958L;      /* 42 */
    return (int)c;
}

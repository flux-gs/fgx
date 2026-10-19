/* M13 assign-expr acceptance: K&R 'while ((c = f()) >= 0)' idiom. */

int g_n;

int feed(void)
{
    g_n = g_n - 1;
    if (g_n < 0) return 0 - 1;
    return g_n;
}

int main(void)
{
    int c;
    int sum;
    g_n = 7;
    sum = 0;
    while ((c = feed()) >= 0) {
        sum = sum + c;
    }
    return sum + sum;   /* 21 + 21 = 42 */
}

/* M20: long mul / div / mixed arith. */
int main(void)
{
    long a, b;
    a = 100L * 1000L;       /* 100000 */
    b = a / 100L;            /* 1000 */
    a = b * 3L;              /* 3000 */
    a = a - 2958L;           /* 42 */
    return (int)a;
}

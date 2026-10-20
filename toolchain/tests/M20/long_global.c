/* M20: global long, init, read, arith. */
long g = 1000000L;
int main(void)
{
    long c;
    c = g - 999958L;        /* 42 */
    return (int)c;
}

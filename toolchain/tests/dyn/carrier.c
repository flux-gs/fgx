/* A dynamic program's long long and double arithmetic: both go to libc.so's
 * entries (_fcc_ll_*, _fcc_d*), and the high words of their operands travel
 * in _fcc_q2 ... _fcc_qb3.  test_dyn.py's carrier() links this. */
long long a, b;
double x, y;

int
main()
{
    long l;

    l = 3L;
    a = 7;
    b = a * 6;
    x = l;
    y = x * 1.5;
    return (int)b + (int)y;
}

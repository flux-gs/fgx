/* A static local array of a wide element type with an initializer list:
 * double, float, long and long long, one sized from its list.  K&R A.8.7: an
 * initializer for a static object is a list of constant expressions, at any
 * scope; 2.11BSD ntpd's hourly() has `static double drifts[5] = { 0.0, ... }'.
 * Called twice, so the second call sees the first's store.  Returns 42. */

int f()
{
    static double d[3] = { 1.5, 2.5, 3.0 };
    static float fl[2] = { 0.5, 1.5 };
    static long l[] = { 100000L, 7L };
    static long long q[2] = { 5, 6 };

    d[0] += 1.0;
    return (int)(d[0] + d[1] + d[2]) + (int)(fl[0] + fl[1])
         + (int)(l[0] / 10000L) + (int)(l[1]) + (int)(q[1] - q[0])
         + (int)(sizeof l / sizeof l[0]);
}

int main()
{
    int a;

    a = f();                        /* 2.5+2.5+3 = 8, +2, +10, +7, +1, +2 = 30 */
    return f() + a - 19;            /* 31 + 30 - 19 = 42 */
}

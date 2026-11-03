/* A prototype parameter declared `array of T' for a T other than int or
 * char.  K&R A.10.1: "If a parameter is declared to have type `array of
 * type,' the declaration is adjusted to read `pointer to type'".  fcc took
 * the `T name[]' shape for int and char only and refused the rest; 2.11BSD
 * getloadavg(3) declares `double loadavg[]'.  Each callee indexes and
 * writes through its parameter as a pointer.  Returns 42. */
struct pt { int x, y; };

long lsum(long a[], int n)
{
    long s;
    int i;

    s = 0;
    for (i = 0; i < n; i++)
        s += a[i];
    a[0] = 0;
    return s;
}

int ptsum(struct pt p[], int n)
{
    int s, i;

    s = 0;
    for (i = 0; i < n; i++)
        s += p[i].x + p[i].y;
    p[1].y = 7;
    return s;
}

long gl[3] = { 100000L, 5L, 7L };
struct pt gp[2] = { { 1, 2 }, { 3, 4 } };

int main(void)
{
    int r;

    r = 0;
    if (lsum(gl, 3) == 100012L && gl[0] == 0)
        r += 20;
    if (ptsum(gp, 2) == 10 && gp[1].y == 7)
        r += 22;
    return r;
}

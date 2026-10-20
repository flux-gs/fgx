/* Audit: compound assign on each lvalue family.
 *   arr[i] += k     (array index)
 *   *p     += k     (pointer deref)
 *   s.v    += k     (struct field)
 * If any target's RMW reads from a stale address, sum diverges from 42. */

typedef struct { int v; } S;

int main()
{
    int a[3];
    int n;
    int *p;
    S s;

    a[0] = 5;
    a[1] = 10;
    a[2] = 7;
    a[1] += 8;     /* a[1] = 18 */

    n = 3;
    p = &n;
    *p += 7;       /* n = 10 */

    s.v = 0;
    s.v += 14;     /* s.v = 14 */

    return a[1] + n + s.v;   /* 18 + 10 + 14 = 42 */
}

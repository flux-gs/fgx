/* preinc_dot_rvalue: prefix ++/-- on a DOT member in RVALUE position --
 * `x = ++c.m`.  The arrow form `++p->m` already worked as an rvalue, and the
 * dot form already worked as a STATEMENT (`++c.m;`), so this was the one empty
 * cell in that matrix; it died 'expected ;'.
 *
 * 2.11BSD telnetd lands squarely in it:
 *     #define settimer(x)  (clocks.x = ++clocks.system)
 * where ++clocks.system is the rvalue assigned to clocks.x.  K&R A.7.4.1 takes
 * ++/-- on any modifiable lvalue, so the dot form was never special.
 *
 * Routed through the uniform lvalue walker (N_LV_CHAIN + N_LV_INCDEC_E), which
 * is why the chained forms below work too.  -> 42. */
struct I { int v; };
struct O { struct I b; int arr[3]; int m; int n; };

struct O c;

int
main()
{
    int a, b, d, e;

    c.m = 10; c.n = 20;
    c.b.v = 5;
    c.arr[1] = 7;

    a = ++c.m;              /* c.m = 11, a = 11 (NEW value, not old) */
    b = --c.n;              /* c.n = 19, b = 19 */
    d = ++c.b.v;            /* nested dot: c.b.v = 6,  d = 6  */
    e = ++c.arr[1];         /* dot then index: c.arr[1] = 8, e = 8 */

    /* prefix yields the new value, so a/b/d/e must equal the stored fields */
    if (a != c.m || b != c.n || d != c.b.v || e != c.arr[1])
        return 1;

    return a + b + d + e - 2;   /* 11 + 19 + 6 + 8 - 2 == 42 */
}

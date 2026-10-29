/* A pointer to a function pointer, `int (**pp)()'.  K&R A.8.6.1: in `T D'
 * with D of the form `* D1', the identifier's type is "pointer to" the type
 * D1 gives it, so `(**pp)()' is a pointer to a pointer to a function
 * returning int.  A.8.6.3: an array parameter is "altered to" a pointer, so
 * `int (*g[])()' is one too.  Each spelling below must reach the function the
 * pointer points at: a local, a global (initialized, too), a struct member reached by `.' and
 * `->', both parameter styles, a typedef, a cast, pointer arithmetic, a store
 * through the pointer, and sizeof.  Returns 42 when every check holds. */
int add(a) int a; { return a + 1; }
int dbl(a) int a; { return a * 2; }
int neg(a) int a; { return -a; }

int (*t[3])() = { add, dbl, neg };
int (**gpp)();
int (**gi)() = &t[1];                  /* initialized like any pointer */
struct ops { int h; int (**vec)(); } o, *op;
typedef int (**PP)();

int kr(pp) int (**pp)(); { return (*pp)(20); }
int ansi(int (**pp)()) { return pp[1](20); }
int arr(g) int (*g[])(); { return g[2](20); }
int tdp(x) PP x; { return (*x)(1) + x[1](1); }

int main()
{
    int (**pp)();
    int (*fp)();
    int (**lp)() = t + 2;
    char *raw;
    int bad;

    bad = 0;
    pp = t;
    if ((*pp)(1) != 2 || pp[1](3) != 6 || (**pp)(4) != 5) bad++;
    if ((*(pp + 2))(7) != -7 || (*(1 + pp))(5) != 10) bad++;
    gpp = &t[1];
    if ((*gpp)(5) != 10 || gpp[1](5) != -5) bad++;
    if ((*gi)(8) != 16 || (*lp)(8) != -8) bad++;
    o.vec = t;
    op = &o;
    if ((*o.vec)(9) != 10 || o.vec[1](9) != 18) bad++;
    if ((*op->vec)(1) != 2 || op->vec[2](1) != -1) bad++;
    if (kr(t + 1) != 40 || ansi(t) != 40 || arr(t) != -20) bad++;
    if (tdp(t) != 4) bad++;
    raw = (char *)(t + 2);
    if ((*(int (**)())raw)(3) != -3 || ((PP)raw)[0](4) != -4) bad++;
    fp = add;
    pp = &fp;
    *pp = dbl;                          /* store through it */
    if (fp(21) != 42 || pp[0](2) != 4) bad++;
    if (sizeof(int (**)()) != 4 || sizeof(int (*)()) != 4 || sizeof pp != 4)
        bad++;
    return bad ? bad : 42;
}

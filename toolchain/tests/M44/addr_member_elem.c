/* The address of an element of an array member, for every element type and
 * both member operators.  K&R A.7.3.1: "the type of the subscript expression
 * is T", for any T, and A.7.4.2: & of an lvalue of type T is a "pointer to
 * T" -- so `&c.a[1]' with `char *a[2]' is a char **.  Each address is stored
 * through and the member read back directly, so a wrong stride or offset
 * lands in the wrong element.  Covers a static base, a local base and a
 * pointer base, a rank-2 member, and the address under a cast.  Returns 42
 * when every check holds. */
struct e { int x; int y; };
struct s {
    int      h;
    char    *a[3];
    long     l[3];
    double   d[3];
    struct e se[3];
    int      m[2][3];
};
struct s c, *cp;
char *one = "one", *two = "two";

int fill(p) struct s *p;
{
    char **q;
    long *lp;
    double *dp;
    struct e *ep;
    int *mp, bad;

    bad = 0;
    q = &p->a[1];  *q = two;
    lp = &p->l[2]; *lp = 70000L;
    dp = &p->d[1]; *dp = 2.5;
    ep = &p->se[2]; ep->y = 9;
    mp = &p->m[1][2]; *mp = 12;
    if (p->a[1] != two || p->a[0] != 0 || p->a[2] != 0) bad++;
    if (p->l[2] != 70000L || p->l[1] != 0) bad++;
    if (p->d[1] != 2.5 || p->d[0] != 0.0) bad++;
    if (p->se[2].y != 9 || p->se[1].y != 0) bad++;
    if (p->m[1][2] != 12 || p->m[1][1] != 0) bad++;
    return bad;
}

int main()
{
    struct s loc;
    char **q;
    long *lp, v;
    double *dp;
    struct e *ep;
    int *mp, bad, i;

    bad = 0;
    q = &c.a[2];  *q = one;
    lp = &c.l[1]; *lp = 123456L;
    dp = &c.d[2]; *dp = 0.5;
    ep = &c.se[1]; ep->x = 5;
    mp = &c.m[0][1]; *mp = 7;
    if (c.a[2] != one || c.a[1] != 0) bad++;
    if (c.l[1] != 123456L || c.l[2] != 0) bad++;
    if (c.d[2] != 0.5 || c.d[1] != 0.0) bad++;
    if (c.se[1].x != 5 || c.se[0].x != 0) bad++;
    if (c.m[0][1] != 7 || c.m[0][2] != 0 || c.m[1][0] != 0) bad++;
    v = (long)&c.a[1];                 /* the address under a cast */
    if (v != (long)(c.a + 1)) bad++;

    for (i = 0; i < 3; i++) {
        loc.a[i] = 0; loc.l[i] = 0; loc.d[i] = 0.0;
        loc.se[i].x = 0; loc.se[i].y = 0;
    }
    for (i = 0; i < 3; i++) { loc.m[0][i] = 0; loc.m[1][i] = 0; }
    q = &loc.a[1]; *q = two;
    mp = &loc.m[1][0]; *mp = 4;
    if (loc.a[1] != two || loc.a[0] != 0 || loc.m[1][0] != 4 ||
        loc.m[0][2] != 0)
        bad++;

    c.a[2] = 0; c.l[1] = 0; c.d[2] = 0.0; c.se[1].x = 0; c.m[0][1] = 0;
    cp = &c;
    bad += fill(cp);
    return bad ? bad : 42;
}

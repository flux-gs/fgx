/* A long double right operand in assignment statements and stores
 * (apple/fgx#447).  K&R A.7.17: "E1 op= E2 is equivalent to E1 = E1 op
 * (E2)", so the operation is at the long double's width and the result is
 * converted to E1's type; A.6.7: "a void cast documents the discarding of the
 * value", so `(void)d' computes nothing from it.  Covered: op= statements on
 * a float local, global, array element, struct member through `.' and `->',
 * and `*p'; on an int and a long; and plain stores of a long double through
 * `*p', `p->f' and `a[i]' into a float, in statement and expression context.
 * Each value is exact in a float, so a narrow operation (1.5 taken as its
 * low four bytes, 0) or an unconverted store gives a different one.  A
 * failing check returns its number; all passing returns 42. */
struct s { int t; float f; };

float gf;
float ga[3];
struct s gs;

int
main()
{
    long double d, h;
    float f, *pf, r;
    struct s *ps;
    int i;
    long l;

    d = 1.5L;
    h = 0.25L;
    ps = &gs;
    pf = &ga[2];

    f = 2;      f += d;         if (f != 3.5f) return 1;
    gf = 2;     gf -= h;        if (gf != 1.75f) return 2;
    ga[1] = 2;  ga[1] *= d;     if (ga[1] != 3.0f) return 3;
    gs.f = 3;   gs.f /= d;      if (gs.f != 2.0f) return 4;
    ps->f = 1;  ps->f += h;     if (gs.f != 1.25f) return 5;
    *pf = 4;    *pf -= d;       if (ga[2] != 2.5f) return 6;
    i = 7;      i += d;         if (i != 8) return 7;
    l = 70000L; l *= d;         if (l != 105000L) return 8;

    *pf = d;                    if (ga[2] != 1.5f) return 9;
    ps->f = h;                  if (gs.f != 0.25f) return 10;
    ga[0] = d;                  if (ga[0] != 1.5f) return 11;
    r = (*pf = h);              if (r != 0.25f || ga[2] != 0.25f) return 12;
    r = (ps->f = d);            if (r != 1.5f || gs.f != 1.5f) return 13;

    (void)d;
    (void)(d + h);
    return 42;
}

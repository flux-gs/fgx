/* paren_postincdec_value: postfix '++'/'--' on a PARENTHESIZED lvalue in VALUE
 * position.  K&R A.7.2 (p.162): "A parenthesized expression is a primary
 * expression whose type and value are identical to those of the unadorned
 * expression.  The precedence of parentheses does not affect whether the
 * expression is an lvalue."  So `(E)++' is `E++'.  The statement form compiled
 * (G41's splice); value position died at "expected ';'" for every spelling
 * except `(*p)++' on an int or pointer leaf (apple/fgx#448).  Each check
 * asserts the yielded OLD value and the store.  -> 42. */
struct s { int m; char *w; };
typedef int Int;

int  g;
long gl;
char buf[4];

int
main()
{
    int   n, x, a[3], *ip;
    long  l, lv, *lp;
    char *p, *q, **cp;
    struct s sv, *sp;

    n = 5;
    x = (n)++;      if (x != 5  || n != 6) return 1;
    x = (n)--;      if (x != 6  || n != 5) return 2;
    x = -(n)++;     if (x != -5 || n != 6) return 3;
    x = !(n)--;     if (x != 0  || n != 5) return 4;
    x = ((n))++;    if (x != 5  || n != 6) return 5;

    g = 7;
    x = (g)++;      if (x != 7 || g != 8) return 6;

    l = 70000L;
    lv = (l)++;     if (lv != 70000L || l != 70001L) return 7;
    gl = 65535L;
    lv = (gl)++;    if (lv != 65535L || gl != 65536L) return 8;

    buf[0] = 10; buf[1] = 20; buf[2] = 30; buf[3] = 40;
    p = buf;
    x = *(p)++;     if (x != 10 || p != buf + 1) return 9;
    x = *(p)--;     if (x != 20 || p != buf)     return 10;
    x = *((p))++;   if (x != 10 || p != buf + 1) return 11;

    /* A char leaf is an 8-bit RMW: 255 wraps to 0 and buf[2] is untouched. */
    q = buf + 1;
    buf[1] = 255;
    x = (*q)++;     if (x != 255 || buf[1] != 0 || buf[2] != 30) return 12;
    cp = &q;
    x = (**cp)--;   if (x != 0 || buf[1] != 255 || buf[2] != 30) return 13;

    a[1] = 100; a[2] = 3;
    ip = &a[1];
    x = (*ip)++;    if (x != 100 || a[1] != 101 || a[2] != 3) return 14;

    lv = 65535L;
    lp = &lv;
    l = (*lp)++;    if (l != 65535L || lv != 65536L) return 15;

    sv.m = 9; sp = &sv;
    x = (sv.m)++;   if (x != 9  || sv.m != 10) return 16;
    x = (sp->m)--;  if (x != 10 || sv.m != 9)  return 17;
    sv.w = buf;
    p = (sp->w)++;  if (p != buf || sv.w != buf + 1) return 18;

    a[0] = 1;
    x = (a[0])++;       if (x != 1 || a[0] != 2) return 19;
    x = (a[0])++ * 2;   if (x != 4 || a[0] != 3) return 20;

    /* A cast of a PREFIX increment is not a grouping: `(Int)++n' is ++n. */
    n = 3;
    x = (Int)++n;   if (x != 4 || n != 4) return 21;

    return 42;
}

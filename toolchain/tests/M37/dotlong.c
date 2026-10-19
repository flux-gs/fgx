/* H1-date regression: long/float compound-assign + prefix ++/-- on a
 * STRUCT DOT-FIELD (S_COMPOUND_DOTFIELD long arm + the ++x.f desugar).
 * date(1)'s gtime tail is the load-bearing user: `tv.tv_sec += ...` with
 * int and long RHS, and `++tv.tv_sec`.  Exit 42. */
struct tv { long sec; int pad; };
struct tv g;

int main(void)
{
    struct tv l;

    g.sec = 0x00010000L;
    g.sec += 60;                    /* long field += int const */
    if (g.sec != 0x0001003cL) return 1;
    ++g.sec;                        /* prefix ++ on dot-field */
    if (g.sec != 0x0001003dL) return 2;
    --g.sec;
    g.sec += g.sec;                 /* long field += long (hi word live) */
    if (g.sec != 0x00020078L) return 3;
    l.sec = 0x00030001L;
    l.sec += 2;                     /* LOCAL struct long field += int */
    if (l.sec != 0x00030003L) return 4;
    ++l.sec;
    if (l.sec != 0x00030004L) return 5;
    return 42;
}

/* arrfield.c — correctness queue 2: array-field element compound assign
 * (s.la[i] op= v / p->fa[i] op= v — the FIELD twin of M28/f_acompound)
 * + float scalar-field brace-init (struct T g = {2.5, ...}).
 * Both were fail-closed dies before the 2026-07-10 fixes.  All standard
 * C — clang cross-checks at the same exit code.  Exit 42. */
struct S {
    int  n;
    long la[3];
    float fa[3];
    unsigned int ua[2];
    int  ia[2];
    char ca[4];
};
struct T { float x; long y; int z; };

struct T ginit = {2.5, 70000L, 3};   /* float field brace-init (2a) */
struct S gs;
struct S *gp;

int main()
{
    int r = 0;

    gp = &gs;

    gs.la[1] = 70000L;
    gs.la[1] += 5L;              /* long, dot */
    gp->la[1] -= 70000L;         /* long, arrow */
    if (gs.la[1] == 5L) r += 10;

    gs.fa[2] = 2.0;
    gs.fa[2] *= 2.25;            /* float, dot: 4.5 */
    gp->fa[2] += 0.5;            /* float, arrow: 5.0 */
    if (gs.fa[2] == 5.0) r += 10;

    gs.ca[1] = 3;
    gs.ca[1] += 2;               /* char, dot */
    if (gs.ca[1] == 5) r += 5;

    gs.ua[0] = 40000;
    gs.ua[0] /= 10000;           /* unsigned int elem: 4 (signed would be -2) */
    r += (int)gs.ua[0];

    gs.ia[0] = 3;
    gs.ia[0] *= 4;               /* int, dot: 12 */
    gp->ia[0] -= 9;              /* int, arrow: 3 */
    r += gs.ia[0];

    if (ginit.x == 2.5) r += 4;
    if (ginit.y == 70000L) r += 3;
    r += ginit.z;

    return r;                    /* 10+10+5+4+3+4+3+3 = 42 */
}

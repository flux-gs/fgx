/* depth2.c — correctness queue 4: B-3 depth-2 leftovers closed.
 *   4a: depth-2+ pointer STRUCT FIELDS (`char **pp;`) declare and
 *       read/write through (was an artificial single-star reject).
 *   4b: `*GLOBALPTR op= v` (deref compound through a global pointer —
 *       the local fast path's twin).
 *   Regression pins: (char **) cast of a void*, pp[i] = q indexed
 *   store, deref-store through a global char**.
 * All standard C — clang cross-checks the exit.  Exit 42. */
char gbuf[8];
char b2[4];
char *gs;
char *ga[3];
char **gpp;
void *gv;

struct D { char **pp; int n; };
struct D gd;

int main()
{
    int r = 0;

    /* 4a: depth-2 field — store the pointer-to-pointer, read through. */
    gs = gbuf;
    gd.pp = &gs;
    gbuf[0] = 10;
    r += (*gd.pp)[0];                 /* +10 */

    /* 4a: write THROUGH the field (retarget gs via the field). */
    b2[0] = 7;
    *gd.pp = b2;
    r += gs[0];                       /* +7 */

    /* 4b: deref compound through a GLOBAL char**. */
    gs = gbuf;
    gpp = &gs;
    gbuf[3] = 9;
    *gpp += 3;                        /* gs advances 3 */
    r += gs[0];                       /* +9 */

    /* pins: (char **) cast round-trip; pp[i] = q.  (The INLINE
     * `(*(char **)gv)[0]` compound shape stays unsupported — cast to a
     * named char** first.) */
    gs = gbuf;
    gv = (void *)&gs;
    gbuf[0] = 6;
    gpp = (char **)gv;
    r += (*gpp)[0];                   /* +6 */

    gpp = ga;
    gpp[1] = b2;
    b2[0] = 8;
    r += gpp[1][0];                   /* +8 */

    gs = gbuf + 5;
    gpp = &gs;
    gbuf[2] = 2;
    *gpp -= 3;                        /* -= form: gs back to gbuf+2 */
    r += gs[0];                       /* +2 */

    return r;                         /* 10+7+9+6+8+2 = 42 */
}

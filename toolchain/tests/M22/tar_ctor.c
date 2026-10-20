/* tar_ctor — regression for the four fcc constructs the 2.11BSD tar(1) port
 * surfaced (all previously rejected/miscompiled):
 *   1. `int *m[] = { a1, a2 }` — array-name decay in a pointer-array init.
 *   2. `sizeof(u.s.arr)` — sizeof of a nested struct/union member.
 *   3. `&u.s.arr[i]` — address of a 2-hop member-array element.
 *   4. `a[i].m = b[j].m = 0` — chained store through struct-array element
 *      members (expression-context, value-yielding).
 *   5. `v[n] = 0` where v is `char **` (T** subscript STORE) — the element
 *      stride must be 4 (a far pointer), not 2.  With the ×2 bug, `argv[argc]=0`
 *      wrote to &argv[argc/2], clobbering a live arg (broke tar's `f` option).
 *      Exercised for both a local and a `char **`/`char *[]` param.
 * Returns 42 iff all five behave correctly. */

struct h { char name[4]; char sum[8]; };
union  u { char d[16]; struct h hb; } blk;

int a1[] = { 10, 20 };
int a2[] = { 30, 40 };
int *m[] = { a1, a2 };                 /* (1) */

struct tv { long s; long u; };

/* (5) param char**: null v[n], report whether the OTHER slots survived. */
int nullslot(v, n)
    char **v;
    int n;
{
    v[n] = 0;
    return (v[0] != 0 && v[1] != 0 && v[3] != 0);   /* only [2] should die */
}

int main()
{
    struct tv v[2];
    char *cp;
    char *pp[4];
    int n, ok;

    ok = 1;

    /* (1) pointer-array of decayed arrays */
    if (m[0][1] != 20 || m[1][0] != 30) ok = 0;

    /* (2) sizeof nested member array == 8 */
    n = sizeof(blk.hb.sum);
    if (n != 8) ok = 0;

    /* (3) &2-hop member elem: clear sum[0..7] to '*' via the end-pointer idiom.
     * sum is at union offset 4 (after name[4]), so blk.d[4] overlaps sum[0]. */
    for (cp = blk.hb.sum; cp < &blk.hb.sum[sizeof(blk.hb.sum)]; cp++)
        *cp = '*';
    if (blk.hb.sum[0] != '*' || blk.hb.sum[7] != '*' || blk.d[4] != '*')
        ok = 0;

    /* (4) chained store through struct-array element members */
    v[0].u = v[1].u = 7;
    if (v[0].u != 7 || v[1].u != 7) ok = 0;
    v[0].s = v[1].s = 0;
    if (v[0].s != 0 || v[1].s != 0) ok = 0;

    /* (5) T** subscript STORE, local base: pp[2]=0 must null slot 2 only
     * (stride 4).  The ×2 bug wrote pp+2*2 = &pp[1], sparing pp[2]. */
    pp[0] = "a"; pp[1] = "b"; pp[2] = "c"; pp[3] = "d";
    n = 2;
    pp[n] = 0;
    if (pp[2] != 0) ok = 0;                      /* slot 2 must be cleared */
    if (pp[0] == 0 || pp[1] == 0 || pp[3] == 0) ok = 0;  /* others intact */

    /* (5b) same, but through a char** PARAM (tar's argv[argc]=0 shape). */
    pp[0] = "a"; pp[1] = "b"; pp[2] = "c"; pp[3] = "d";
    if (!nullslot(pp, 2)) ok = 0;                /* others survive the null */
    if (pp[2] != 0) ok = 0;

    return ok ? 42 : 1;
}

/* charptr_arr_global: a bare global ARRAY name as a char*[] initializer item.
 * A global array decays to its address (a char*), so it is a valid static
 * initializer alongside string literals, '&global', and 0 -- matching tcsh's
 *   Char *dumphist[] = {STRhsto, STRmh, 0, 0};        (sh.c, file scope)
 *   static Char *pv[2] = {STRNULL, NULL};             (tw.parse, static local)
 * where STRxxx are `Char STRxxx[]` const arrays.  fcc's char*[] init walkers
 * (file-scope and static-local) previously required a string literal.  -> 42. */
char aa[] = "AB";                    /* global array; aa decays to &aa[0] */
char bb[] = "CD";

/* file-scope char*[]: bare array name, &global, string literal, 0 */
char *tbl[] = {aa, bb, "EF", 0};

int
scount()
{
    static char *pv[3] = {aa, bb, 0};   /* static-local: bare array names + 0 */
    int n = 0;
    while (pv[n] != 0) n++;             /* 2 */
    return n;
}

int
main()
{
    int sum = 0;
    /* tbl[0]=aa -> "AB", tbl[1]=bb -> "CD", tbl[2]="EF", tbl[3]=0 */
    sum = sum + tbl[0][0];             /* 'A' == 65 */
    sum = sum + (tbl[3] == 0 ? 1 : 0); /* NULL slot -> +1  == 66 */
    sum = sum + scount();              /* +2 == 68 */
    return sum - 26;                   /* 68 - 26 == 42 */
}

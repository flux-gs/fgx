/* compress secondary-hash PROBE path (Fable rank-1): index computed via
 * i -= disp (transiently NEGATIVE), then i += hsize_reg (wrap), then
 * htab[i]/codetab[i] subscript.  A 28-byte input has no collisions so never
 * runs this; 616 bytes does.  Also exercises (long)htab[i] > 0 / < 0 sign
 * tests used to continue/stop the probe.  Exit 42. */
typedef long code_int;
typedef long count_int;
count_int *htab;
unsigned short *codetab;
long   hstore[5010];
unsigned short cstore[5010];

int main(void)
{
    register code_int i, hsize_reg;
    register int disp;
    long fcode;
    int k;

    htab = hstore; codetab = cstore;
    for (k = 0; k < 5010; k++) { htab[k] = -1L; codetab[k] = 0; }

    hsize_reg = 5003;
    fcode = 0x0006E065L;                 /* 450661 */

    /* seed a slot the probe will land on */
    htab[200] = fcode; codetab[200] = 77;

    i = 100;
    disp = hsize_reg - i;                /* 4903 */
    if (i == 0) disp = 1;
probe:
    if ((i -= disp) < 0)                 /* 100-4903 = -4803 (negative long) */
        i += hsize_reg;                  /* -4803 + 5003 = 200 (wrap)        */
    if (i != 200) return 1;              /* index computed right?            */

    if (htabof_eq(i, fcode)) {           /* htab[i]==fcode via probe index   */
        if (codetab[i] != 77) return 2;
        if (htab[i] != fcode) return 3;
        if ((long) htab[i] <= 0) return 4;   /* sign test used in probe      */
        htab[i] = fcode;                 /* store via probe index            */
        codetab[i] = 88;
        if (cstore[200] != 88) return 5;
        if (hstore[200] != fcode) return 6;
        return 42;
    }
    return 7;
}

int htabof_eq(x, f) code_int x; long f; { return htab[x] == f; }

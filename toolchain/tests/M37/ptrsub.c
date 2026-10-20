/* B-3'' regression: compound assignment through a POINTER-variable
 * subscript (p[i] op= v).  The old emission pushed the element address
 * as 2 bytes but the deref store-back read a bank at 3,S and popped 4 —
 * garbage-bank write + a corrupted (negative) emitter depth ledger that
 * turned every later local read in the function into stack garbage
 * (the jsh fgetc boot wedge: e[1] |= _IOEOF never made EOF visible).
 *
 * After the |=, later locals must still read correctly.  10+16+8+8 = 42. */
int  wtab[4];
char ctab[4];

int main(void)
{
    int  *p = wtab;
    char *c = ctab;
    int ok = 10;                 /* the post-op local read that went garbage */

    wtab[1] = 0x03;
    p[1] |= 0x10;                /* word compound through ptr subscript */
    ctab[2] = 0x21;
    c[2] &= 0x0F;                /* byte compound through ptr subscript */

    if (wtab[1] == 0x13) ok += 16;
    if (ctab[2] == 0x01) ok += 8;
    if (ok > 0)          ok += 8;    /* ok itself survived the ledger */
    return ok;
}

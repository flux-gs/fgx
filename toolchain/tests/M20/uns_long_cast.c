/* M20 / A-1: (long)(unsigned short) MUST zero-extend, not sign-extend.
 *
 * Mirrors od(1)'s us_put: `unsigned short *n; icvt((long)*n, ...)`.  For a
 * short with bit 15 set (here 0xab4b) a sign-extend yields 0xffffab4b — a
 * negative long — which drove od's icvt unsigned-emulation branch into a hang
 * (od -hc on any binary froze on the first short >= 0x8000).  The correct
 * zero-extend gives 0x0000ab4b.  Returns 42 only when the deref+widening
 * zero-extends; the old sign-extending codegen returns 1. */
int main(void)
{
    unsigned short  v;
    unsigned short *n;
    long            x;

    v = 0xab4b;
    n = &v;
    x = (long)*n;
    if (x == 0xab4bL)
        return 42;
    return 1;
}

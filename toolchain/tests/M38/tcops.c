/* T5-C C4 batch 10: the termcap surface in C over the baked-vt100 asm
 * engines (LIBC_DP_LP0 staging via __asm; tgetstr's cap string comes
 * back with the DATA bank recovered in C).
 *
 * tgetstr MUST be declared: an implicit int-return default makes the
 * caller rebuild the pointer with bank 0 (the trap that got tgetstr
 * mis-parked as an fcc cast bug).  *cm == 27 (ESC) is bank-sensitive:
 * a bank-0 misread cannot fake the vt100 cm cap's leading ESC.
 *
 * FGX-only (MAME oracle).  14+14+7+7 = 42. */
extern char *tgetstr();

int main(void)
{
    char *cm;
    int r = 0;

    if (tgetent((char *)0, "vt100") == 1)  r += 14;
    if (tgetnum("co") == 80)               r += 14;
    cm = tgetstr("cm", (char **)0);
    if (cm != 0 && *cm == 27)              r += 7;
    if (tgetflag("zz") == 0)               r += 7;
    return r;
}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * tgstest.c -- FGX2 multi-bank tgetstr() sanity fixture.
 *
 * The c_tgetstr/c_tgetnum/c_tgetflag adapters (fcc_libc_shims.s) bridge fcc's
 * far-pointer ABI to the register-ABI tgetstr/tgetnum/tgetflag (libc.s).  Under
 * FGX2 this exposed two same-class bank bugs, both invisible in single-bank FGX1:
 *   (1) cap-NAME read: the adapter used the arg's offset only, under DBR=seg1,
 *       but the cap-name string literal can live in seg0 (--data-segment keeps
 *       the string pool in the code seg) -> wrong bank -> lookup MISS (NULL).
 *   (2) cap-STRING return: on a hit the adapter set the result's far-ptr bank
 *       to PHK (the code bank), but the baked cap strings (tc_*, libc_data.s)
 *       live in seg1 (data) -> caller reads the wrong bank -> garbage.
 * elvis (--far-calls, cap names in the data seg) hit (2) -> its screen-init
 * garble.  Fix: adapter passes the cap-name FAR ptr via LIBC_DP_LP0 (tget* read
 * it bank-aware via [LP0],Y) and returns bank=DBR.
 *
 * A correct "cl"/"cm" cap begins with ESC (0x1B).  This binary exits 42 iff
 * both caps read back correctly; distinct codes pinpoint the failure:
 *   2  tgetstr("cl") miss (NULL) -> cap-name wrong-bank read (bug 1)
 *   3  cl[0] != ESC  -> cap-string wrong-bank return (bug 2)
 *   4  tgetstr("cm") miss (NULL) -> bug 1
 *   5  cm[0] != ESC  -> bug 2
 *  42  both caps correct
 */

int   tgetent(char *bp, char *name);
char *tgetstr(char *id, char **area);

char termbuf[128];
char capbuf[128];

int main(void)
{
    char *area = capbuf;
    char *cl;
    char *cm;

    tgetent(termbuf, "fgx");

    cl = tgetstr("cl", &area);
    if (cl == 0)     return 2;
    if (cl[0] != 27) return 3;

    cm = tgetstr("cm", &area);
    if (cm == 0)     return 4;
    if (cm[0] != 27) return 5;

    return 42;
}

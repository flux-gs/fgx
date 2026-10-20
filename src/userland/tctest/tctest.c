/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libtermlib tc3(1) test
 *   Ported from libtermlib tc3.c 5.1 (Berkeley, 6/5/85), the dummy program
 *   that exercises termlib's tgoto.
 *   Original work: Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX changes
 *   are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * tctest -- deterministic self-test for the termcap library's tgoto (the
 * cursor-addressing %-escape expander; see toolchain/lib/libtermlib_c/).  Looks up the
 * "up" and "cm" caps from the baked "fgx" entry, then runs a fixed set of
 * (a,b) coordinates through tgoto and prints each generated string in tc3's
 * readable ^-notation (ESC -> "^[", etc.).  Because the FGX terminal's
 * cm = ESC[%i%d;%dH, tgoto(CM,a,b) yields ESC[<b+1>;<a+1>H, so the output is
 * fully deterministic and asserted byte-for-byte by the MAME test.
 *
 * FGX/fcc adaptations (no behaviour change):
 *  - Upstream loops reading "a b" pairs via scanf; fcc has no scanf, so the
 *    coordinate set is a fixed, unrolled list (tcline calls) -- a self-test
 *    instead of an interactive prompt.  Prints escapes as text; it does NOT
 *    move the cursor (faithful to tc3, which is an inspection harness).
 *  - tgoto/tputs come from libtermlib (BSD-foundations P1; libs="termlib").
 *    libtermlib defines UP and BC, as 2.11BSD's tgoto.c does; the
 *    declarations below are tentative definitions, which K&R A.10.2's
 *    common extension merges with termlib's.
 *  - isprint() hand-rolled (no <ctype.h>); getenv("TERM") is NULL on FGX so we
 *    default to the baked "fgx" entry; "%x"-of-pointer diagnostic dropped.
 */

#include <stdio.h>

/* termlib's tgoto cells (tentative: termlib's definitions win) + the
 * RTL-ABI empty-paren decls (termlib compiles tgoto/tputs behind K&R
 * forward decls; callers must match). */
char *UP;
char *BC;
char *tgoto();
void  tputs();

/* libc decls not from <stdio.h>. */
void  exit(int code);
char *getenv(char *name);
int   tgetent(char *bp, char *name);
char *tgetstr(char *id, char **area);

char buf[1024];                         /* tgetent entry buffer (baked entry ignores it) */
char cmbuff[64];                        /* tgetstr area */
char *CM;
char rdbuf[4];                          /* rdchar result */

/* ANSI forward prototypes. */
int   main(int argc, char **argv);
int   tc_isprint(int c);
char *rdchar(int c);
void  pr(char *p);
void  tcline(int a, int b);

int tc_isprint(int c)
{
    return c >= 0x20 && c < 0x7F;
}

/* Readable representation of an ASCII char in ^-notation (from tc3 rdchar). */
char *rdchar(int c)
{
    char *p;

    rdbuf[0] = ((c & 0377) > 0177) ? '\'' : ' ';
    c &= 0177;
    rdbuf[1] = tc_isprint(c) ? ' ' : '^';
    rdbuf[2] = tc_isprint(c) ?  c  : (c ^ 0100);
    rdbuf[3] = 0;
    for (p = rdbuf; *p == ' '; p++)
        ;
    return p;
}

void pr(char *p)
{
    for (; *p; p++)
        printf("%s", rdchar(*p));
}

/* Run one (a,b) coordinate through tgoto and print it readably. */
void tcline(int a, int b)
{
    printf("%d %d -> ", a, b);
    pr(tgoto(CM, a, b));
    printf("\n");
}

int main(int argc, char **argv)
{
    char *p;
    char *x;

    p = (argc < 2) ? getenv("TERM") : argv[1];
    if (p == NULL)                      /* FGX has no environ -> baked entry */
        p = "fgx";
    tgetent(buf, p);

    x = cmbuff;
    UP = tgetstr("up", &x);
    printf("UP = ");
    pr(UP);
    printf("\n");
    if (UP && *UP == 0)
        UP = 0;
    CM = tgetstr("cm", &x);
    printf("CM = ");
    pr(CM);
    printf("\n");

    tcline(0, 0);
    tcline(5, 10);
    tcline(23, 79);
    tcline(9, 9);
    tcline(12, 40);

    printf("TCDONE\n");
    return 0;
}

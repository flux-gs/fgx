/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libtermlib (usr.lib/libtermlib)
 *   tgoto/tputs ported from libtermlib tgoto.c 5.1 + tputs.c 5.1 (Berkeley,
 *   6/5/85), previously FGX src/userland/lib/termcap.c (textual-include TU).
 *   Original work: Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX changes
 *   are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * lib/libtermlib_c/libtermlib.c -- this source builds three artifacts:
 * `libtermlib.so` (the shared library, linked against libc.so and
 * libfgx.so; what every tool links); build/static_libs/libtermlib.s, the
 * program-mode compile the fcc fixtures' termlib recipe links; and
 * `lib/libtermlib.s`, a --pile-far-extern whole-graph aggregate kept only as
 * the termcap stack-check in tests/run.sh.
 *
 * tgetent/tgetflag/tgetnum/tgetstr are the C bridge over the baked-vt100
 * asm engines (_tc_* in libc.s, tc_* tables in libc_data) — those stay libc
 * internals; the bridge near-JSRs them at co-assembly.
 *
 * UP, BC, PC and ospeed are DEFINED here, as 2.11BSD's libtermlib defines
 * them (tgoto.c: `char *UP; char *BC;', tputs.c: `short ospeed; char PC;').
 * A program or curses that also defines them tentatively shares these
 * cells under K&R A.10.2's common extension (fgx_gc and gen_commons merge
 * them).
 *
 * FGX/fcc adaptations carried over from termcap.c (no behaviour change):
 *  - tputs applies NO padding delay (no serial baud timing on a memory-
 *    mapped SHR console; equivalent to upstream ospeed==0).  The padding
 *    spec (digits[.digit]['*']) is still parsed + skipped.
 *  - tc_isdigit hand-rolled (no <ctype.h>).
 *  - tgoto/tputs get EMPTY-PAREN forward decls (K&R "unspecified args") so
 *    fcc's right-to-left varargs ABI flips the callee's param offsets to
 *    match elvis's `extern char *tgoto();` call sites.  A full ANSI
 *    prototype would leave the callee un-flipped and mismatch.
 *  - CTRL(d) keeps upstream's literal-'c' quirk (only reached by the
 *    %./%+ path, which our cm=ESC[%i%d;%dH never takes).
 */

/* libc decls (fcc needs a prototype even for bound calls). */
char *strcpy(char *d, char *s);
char *strcat(char *d, char *s);

/* fcc_runtime_data.s staging cells (see libc_c.c: dedicated cells, NOT
 * _fcc_* scratch). */
extern char *__asm_p0;
extern int   __asm_w0;
extern int   __asm_w1;

/* tgoto's cursor-up and backspace strings and tputs's pad character and
 * speed, defined here as 2.11BSD's libtermlib defines them (tgoto.c,
 * tputs.c).  A program or curses that also defines them tentatively
 * shares these cells (K&R A.10.2's common extension). */
char *UP;
char *BC;
char  PC;
short ospeed;

/* ANSI forward prototypes. */
int   tc_isdigit(int c);
/* RTL-ABI: EMPTY parens on purpose — see the header comment. */
char *tgoto();
void  tputs();
int   strcmp();                          /* tgetent's entry-name match */

#define CTRL(c) ('c' & 037)
#define MAXRETURNSIZE 64

/* ---- tgetent/tgetflag/tgetnum/tgetstr — the baked-termcap bridge --------- */

/* tgetent - select which baked entry the tget* lookups answer from.
 *
 * It used to `return 1' and ignore BOTH arguments, so every terminal was
 * described by the IIgs console's entry -- which is wrong for a remote terminal
 * in a way that corrupts the display (apple/fgx#147: the console wraps at the
 * last column, an xterm defers the wrap, and elvis asks with
 * `tgetflag("am") && !tgetflag("xn")').
 *
 * `bp' IS STILL IGNORED, deliberately.  A real termcap writes up to 1024 bytes
 * of entry text there, and three callers in this tree pass a 32-byte buffer
 * because this function never used it -- ul(1) even records that a
 * termcap[1024] local overflows the frame.  Reading entries from /etc/termcap
 * is the BSD shape and remains the right end state, but it is a change to every
 * caller's buffer, not to this function, so it is left as its own piece of work
 * rather than smuggled in behind a signature that looks unchanged.
 *
 * An unknown name gets the console entry, which is what every caller got
 * before, so nothing degrades by being unrecognised.
 */
int tgetent(char *bp, char *name)
{
    int ansi;

    ansi = 0;
    if (name != (char *)0
        && (strcmp(name, "fgxpty") == 0
            || strcmp(name, "xterm") == 0
            || strcmp(name, "vt100") == 0
            || strcmp(name, "vt102") == 0
            || strcmp(name, "ansi")  == 0))
        ansi = 1;

    __asm_w0 = ansi;
    __asm(
        "LDA __asm_w0",
        "JSR _tc_setent"
    );
    return 1;
}

int tgetflag(char *id)
{
    __asm_p0 = id;
    __asm(
        "LDA __asm_p0",
        "STA LIBC_DP_LP0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA LIBC_DP_LP0+2",
        "REP #$20",
        "MX %00",
        "JSR _tc_getflag",
        "STA __asm_w0"
    );
    return __asm_w0;
}

int tgetnum(char *id)
{
    __asm_p0 = id;
    __asm(
        "LDA __asm_p0",
        "STA LIBC_DP_LP0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA LIBC_DP_LP0+2",
        "REP #$20",
        "MX %00",
        "JSR _tc_getnum",
        "STA __asm_w0"
    );
    return __asm_w0;
}

char *tgetstr(char *id, char **area)
{
    __asm_p0 = id;
    __asm(
        "LDA __asm_p0",
        "STA LIBC_DP_LP0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA LIBC_DP_LP0+2",
        "REP #$20",
        "MX %00",
        "JSR _tc_getstr",
        "STA __asm_w0",
        "LDX #1",
        "BCS @lctlgs_hit",
        "LDX #0",
        "@lctlgs_hit",
        "STX __asm_w1"
    );
    if (__asm_w1 == 0)
        return (char *)0;
    /* Cap strings (tc_*) live in the DATA bank; &UP is built with PHB, so
     * its bank is the process's data bank.  A caller needs tgetstr's
     * prototype, or an implicit int return drops the bank. */
    return (char *)(((unsigned long)(char *)&UP >> 16 << 16)
                    | (unsigned)__asm_w0);
}

/* ---- tgoto/tputs — cursor addressing + (delay-free) padding output ------- */

int tc_isdigit(int c)
{
    return c >= '0' && c <= '9';
}

/*
 * Routine to perform cursor addressing.  CM is a string with printf-type
 * escapes; the escapes substitute row/column:
 *   %d  as printf   %2 like %2d   %3 like %3d   %. like %c (special-char hack)
 *   %+x like %c adding x first
 * State-only (no value): %>xy (if val>x add y)  %r (reverse row/col)
 *   %i (increment, one-origin)  %% (literal %)  %B (BCD)  %D (Delta Data)
 * All other characters are self-inserting.
 */
char *tgoto(char *CM, int destcol, int destline)
{
    static char result[MAXRETURNSIZE];
    static char added[10];
    char *cp = CM;
    char *dp = result;
    int c;
    int oncol = 0;
    int which = destline;

    if (cp == 0) {
toohard:
        /* "We don't do that under BOZO's big top" */
        return ("OOPS");
    }
    added[0] = 0;
    while (c = *cp++) {
        if (c != '%') {
            *dp++ = c;
            continue;
        }
        switch (c = *cp++) {

        case 'd':
            if (which < 10)
                goto one;
            if (which < 100)
                goto two;
            /* fall into... */

        case '3':
            *dp++ = (which / 100) | '0';
            which %= 100;
            /* fall into... */

        case '2':
two:
            *dp++ = which / 10 | '0';
one:
            *dp++ = which % 10 | '0';
swap:
            oncol = 1 - oncol;
setwhich:
            which = oncol ? destcol : destline;
            continue;

        case '>':
            if (which > *cp++)
                which += *cp++;
            else
                cp++;
            continue;

        case '+':
            which += *cp++;
            /* fall into... */

        case '.':
            if (which == 0 || which == CTRL(d) || which == '\n') {
                if (oncol || UP)        /* Assumption: backspace works */
                    do {
                        strcat(added, oncol ? (BC ? BC : "\b") : UP);
                        which++;
                    } while (which == '\n');
            }
            *dp++ = which;
            goto swap;

        case 'r':
            oncol = 1;
            goto setwhich;

        case 'i':
            destcol++;
            destline++;
            which++;
            continue;

        case '%':
            *dp++ = c;
            continue;

        default:
            goto toohard;
        }
    }
    strcpy(dp, added);
    return (result);
}

/*
 * Put the string cp out, with padding.  affcnt = affected lines, outc =
 * single-char output routine.  The padding spec (digits[.digit]['*']) is
 * parsed but no delay is applied (no serial timing on a memory-mapped console).
 */
void tputs(char *cp, int affcnt, int (*outc)(int))
{
    int i = 0;

    if (cp == 0)
        return;

    /* Skip the numeric pad delay (we do not apply it). */
    if (tc_isdigit(*cp)) {
        do
            i = i * 10 + *cp++ - '0';
        while (tc_isdigit(*cp));
    }
    if (*cp == '.') {
        cp++;
        if (tc_isdigit(*cp))
            cp++;
        while (tc_isdigit(*cp))
            cp++;
    }
    if (*cp == '*')
        cp++;

    /* The guts of the string.  fcc calls a function-pointer var by name
     * (outc(c)), not via an explicit deref ((*outc)(c)); same as ul.c. */
    while (*cp) {
        outc(*cp);
        cp++;
    }
}

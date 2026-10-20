/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD cat(1)
 *   Ported from cat(1), 2.11BSD (5.2, Berkeley, 12/6/85).  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * cat - concatenate and print files.  Port of 2.11BSD cat(1).
 *
 * Usage:  cat [-benstuv] [file ...]      (no file, or "-", reads stdin)
 * Flags (2.11BSD copyopt semantics):
 *   -n number all lines      -b number non-blank lines (implies -n numbering
 *                              only on non-blank)
 *   -s squeeze repeated blank lines
 *   -e show line ends as '$' (implies -v)   -t show tabs as ^I (implies -v)
 *   -v show non-printing chars (^X, M-x, ^?)
 *   -u unbuffered (FGX writes go straight to fd 1, so this is a no-op)
 *
 * Port-side notes (FGX / fcc):
 *  - Reads via open()/read(); stdin = fd 0 on no operands or a "-" operand.
 *  - FGX text is CR ($0D) terminated, so the line-oriented flags (-n/-b/-s/-e)
 *    treat CR as the line terminator where 2.11BSD cat uses LF.  Bytes are
 *    still emitted verbatim.
 *  - Line numbers are formatted right-justified in 6 columns by hand (fcc
 *    printf width specifiers are unreliable — cf. dhclient.c / wc.c), matching
 *    2.11BSD's "%6d\t".  Data bytes go out via write() (never printf — file
 *    data can contain '%').
 *  - Dropped (a real FGX gap, not a flag): 2.11BSD's fstat dev/ino "input is
 *    output" guard — FGX has no fstat (SYS_FSTAT is a stub) and stat exposes no
 *    st_dev/st_ino, so `cat f >> f` is not specially detected.
 *  - Buffers are file-scope globals (fcc stack-local arrays are unsafe).
 */
#include <stdio.h>

int open(char *path, int flags);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int close(int fd);

#define O_RDONLY 0
#define BUFSZ    1024
#define NL       0x0d           /* FGX line terminator (CR) */

int  nflg, bflg, sflg, eflg, tflg, vflg, uflg;
int  lno = 1;                   /* next line number (-n/-b) */
int  inln;                      /* chars seen on the current line yet? */
int  spaced;                    /* -s: previous line was blank */
int  curfd;                     /* fd being copied */
int  ibpos, iblen;              /* read-buffer cursor / fill */
char ibuf[BUFSZ];
char o1[1];

void putch(int c)
{
    o1[0] = c;
    write(1, o1, 1);
}

/* next byte (0..255) from curfd, or -1 at EOF. */
int gb(void)
{
    int c;

    if (ibpos >= iblen) {
        iblen = read(curfd, ibuf, BUFSZ);
        if (iblen <= 0)
            return -1;
        ibpos = 0;
    }
    c = ibuf[ibpos];
    ibpos++;
    return c & 0xff;
}

/* emit the current line number right-justified in 6 cols + a tab (= "%6d\t"). */
void emitnum(void)
{
    char d[6];
    int i, n;

    for (i = 0; i < 6; i++)
        d[i] = ' ';
    i = 5;
    n = lno;
    if (n == 0)
        d[5] = '0';
    else
        while (n > 0 && i >= 0) {
            d[i] = (n % 10) + '0';
            n = n / 10;
            i--;
        }
    write(1, d, 6);
    putch('\t');
    lno++;
}

/* copy curfd with -n/-b/-s/-e/-t/-v processing (2.11BSD copyopt, CR-keyed). */
void copyopt(void)
{
    int c;

    for (;;) {
        c = gb();
        if (c < 0)
            return;
        if (c == NL) {
            if (inln == 0) {                    /* blank line */
                if (sflg && spaced)
                    continue;                   /* squeeze repeats */
                spaced = 1;
            }
            if (nflg && bflg == 0 && inln == 0)
                emitnum();
            if (eflg)
                putch('$');
            putch(c);
            inln = 0;
            continue;
        }
        if (nflg && inln == 0)
            emitnum();
        inln = 1;
        if (vflg) {
            if (tflg == 0 && c == '\t') {
                putch(c);
            } else {
                if (c >= 128) {
                    write(1, "M-", 2);
                    c = c & 0x7f;
                }
                if (c < 32) {
                    putch('^');
                    putch(c + '@');
                } else if (c == 127) {
                    putch('^');
                    putch('?');
                } else {
                    putch(c);
                }
            }
        } else {
            putch(c);
        }
        spaced = 0;
    }
}

/* bulk copy curfd -> stdout (no flags). returns 0 ok, 1 read err, 2 write err. */
int fastcat(void)
{
    int n;

    for (;;) {
        n = read(curfd, ibuf, BUFSZ);
        if (n < 0) {
            fprintf(stderr, "cat: read error\n");
            return 1;
        }
        if (n == 0)
            return 0;
        if (write(1, ibuf, n) != n) {
            fprintf(stderr, "cat: write error\n");
            return 2;
        }
    }
}

/* run the selected copier over curfd. */
int catfd(void)
{
    ibpos = 0;
    iblen = 0;
    if (nflg || sflg || vflg) {
        copyopt();
        return 0;
    }
    return fastcat();
}

int main(int argc, char **argv)
{
    int i, fd, rc;
    char *p;

    rc = 0;
    i = 1;
    /* leading flag args (a bare "-" is stdin, not a flag). */
    while (i < argc && argv[i][0] == '-' && argv[i][1] != 0) {
        p = argv[i] + 1;
        while (*p) {
            if (*p == 'u') uflg = 1;
            else if (*p == 'n') nflg = 1;
            else if (*p == 'b') { bflg = 1; nflg = 1; }
            else if (*p == 'v') vflg = 1;
            else if (*p == 's') sflg = 1;
            else if (*p == 'e') { eflg = 1; vflg = 1; }
            else if (*p == 't') { tflg = 1; vflg = 1; }
            else {
                fprintf(stderr, "usage: cat [-benstuv] [file ...]\n");
                return 1;
            }
            p++;
        }
        i++;
    }

    if (i >= argc) {                    /* no file operands -> stdin */
        curfd = 0;
        rc |= catfd();
        return rc;
    }
    for (; i < argc; i++) {
        if (argv[i][0] == '-' && argv[i][1] == 0) {
            fd = 0;                      /* "-" = stdin */
        } else {
            fd = open(argv[i], O_RDONLY);
            if (fd < 0) {
                fprintf(stderr, "cat: cannot open %s\n", argv[i]);
                rc = 1;
                continue;
            }
        }
        curfd = fd;
        rc |= catfd();
        if (fd != 0)
            close(fd);
    }
    return rc;
}

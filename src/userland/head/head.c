/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD head(1)
 *   Ported from head(1), 2.11BSD (5.1, Berkeley, 5/31/85; by Bill Joy, UCB).
 *   Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * head - print the first few lines of each file (or stdin).
 * Port of 2.11BSD head(1).
 *
 * Usage:  head [-n N] [-N] [file ...]      (no file, or "-", reads stdin)
 *   -n N   first N lines (default 10)
 *   -N     2.11BSD form: a count right after the dash, e.g. `head -20 file`
 *
 * Port-side notes (FGX / fcc):
 *  - Reads via open()/read(); stdin = fd 0 on no operands or a "-" operand —
 *    this is the stdin/pipe fallback the hand-asm head lacked (it printed its
 *    usage page as a pipe sink: `cat f | head`), the original reason head was
 *    on the port list.
 *  - Counts lines on CR ($0D), FGX's line terminator (and a lone LF), where
 *    2.11BSD head counts LF; bytes are emitted verbatim.
 *  - With more than one file, prints a "==> name <==" header (2.11BSD), blank
 *    line between files.
 *  - Buffers are file-scope globals (fcc stack-local arrays are unsafe).
 */
#include <stdio.h>

int open(char *path, int flags);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int close(int fd);
int atoi(char *s);

#define O_RDONLY 0
#define BUFSZ    1024

int  linecnt = 10;
int  curfd;
int  ibpos, iblen;
char ibuf[BUFSZ];
char o1[1];

void putch(int c)
{
    o1[0] = c;
    write(1, o1, 1);
}

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

/* emit the first `linecnt` lines of curfd (CR-terminated, lone LF too). */
void copyout(void)
{
    int c, left, prevcr;

    ibpos = 0;
    iblen = 0;
    left = linecnt;
    prevcr = 0;
    while (left > 0) {
        c = gb();
        if (c < 0)
            break;
        putch(c);
        if (c == '\r') {
            left--;
            prevcr = 1;
        } else if (c == '\n') {
            if (!prevcr)
                left--;
            prevcr = 0;
        } else {
            prevcr = 0;
        }
    }
}

int main(int argc, char **argv)
{
    int i, fd, rc, nfiles, first;
    char *a;

    rc = 0;
    i = 1;
    while (i < argc && argv[i][0] == '-' && argv[i][1] != 0) {
        a = argv[i];
        if (a[1] == 'n' && a[2] == 0) {         /* -n N */
            if (i + 1 >= argc) {
                fprintf(stderr, "usage: head [-n N] [file ...]\n");
                return 1;
            }
            linecnt = atoi(argv[i + 1]);
            i += 2;
        } else if (a[1] >= '0' && a[1] <= '9') { /* 2.11BSD -N */
            linecnt = atoi(a + 1);
            i++;
        } else {
            fprintf(stderr, "usage: head [-n N] [file ...]\n");
            return 1;
        }
    }
    if (linecnt < 0)
        linecnt = 0;

    nfiles = argc - i;
    if (nfiles <= 0) {                          /* no operands -> stdin */
        curfd = 0;
        copyout();
        return 0;
    }

    first = 1;
    for (; i < argc; i++) {
        if (argv[i][0] == '-' && argv[i][1] == 0) {
            fd = 0;
        } else {
            fd = open(argv[i], O_RDONLY);
            if (fd < 0) {
                fprintf(stderr, "head: cannot open %s\n", argv[i]);
                rc = 1;
                continue;
            }
        }
        if (!first)
            putch('\n');
        first = 0;
        if (nfiles > 1)
            printf("==> %s <==\n", argv[i]);
        curfd = fd;
        copyout();
        if (fd != 0)
            close(fd);
    }
    return rc;
}

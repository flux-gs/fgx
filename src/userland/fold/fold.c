/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD fold(1)
 *   Ported from fold(1), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * fold - fold long lines for finite output devices.
 * Port of 2.11BSD fold(1) by Bill Joy, UCB 1977.
 *
 * Port-side patches:
 *  - standard ANSI main(int argc, char **argv) signature (fcc binds
 *    argc→args_argc and argv→&args_argv[0], a real 4-byte char**).
 *  - K&R signatures converted to ANSI; forward-declared.
 *  - freopen(argv, "r", stdin) replaced with fopen(argv, "r") into a
 *    local FILE *fp.  freopen isn't shimmed yet (separate libc work)
 *    and the local-fp shape is what wc uses too.
 *  - putchar(c) replaced with fputc(c, stdout) — fcc doesn't bind
 *    putchar; fputc + extern stdout FILE * does the same thing.
 *  - getc(stdin) → fgetc(fp).
 *  - Multi-file loop and stdin path dropped; v1 MVP requires a single
 *    file argument.
 *  - copyright[]/sccsid[] blobs stripped.
 *  - Compound `+=` / `*=` on int globals rewritten as `= x + y` /
 *    `= x * y` (per wc port's discovery that fcc has gaps in compound
 *    assignment on globals at statement position).
 */
#include <stdio.h>

int fold_width;
int col;

void putch(int c);

int main(int argc, char **argv)
{
    int file_idx;
    char *arg;
    char *p;
    int c;
    int n;
    FILE *fp;

    file_idx = 1;
    fold_width = 80;

    /* Parse optional -N (column width). */
    if (argc > 1) {
        arg = argv[1];
        if (arg[0] == '-' && arg[1] != 0) {
            n = 0;
            p = arg + 1;
            while (*p >= '0' && *p <= '9') {
                n = n * 10 + (*p - '0');
                p = p + 1;
            }
            if (*p != 0) {
                printf("Bad number for fold\n");
                return 1;
            }
            fold_width = n;
            file_idx = 2;
        }
    }

    if (file_idx >= argc) {
        printf("Usage: fold [-N] file\n");
        return 1;
    }

    arg = argv[file_idx];
    fp = fopen(arg, "r");
    if (fp == NULL) {
        perror(arg);
        return 1;
    }

    col = 0;
    for (;;) {
        c = fgetc(fp);
        if (c == EOF) break;
        putch(c);
    }
    fclose(fp);
    return 0;
}

void putch(int c)
{
    int ncol;

    /* Compute the column we'd land on if we emitted c without folding. */
    if (c == '\n') {
        ncol = 0;
    } else if (c == '\t') {
        ncol = (col + 8) & ~7;
    } else if (c == '\b') {
        if (col != 0) ncol = col - 1;
        else ncol = 0;
    } else if (c == '\r') {
        ncol = 0;
    } else {
        ncol = col + 1;
    }

    /* If that would push past the fold width, emit a newline first. */
    if (ncol > fold_width) {
        fputc('\n', stdout);
        col = 0;
    }
    fputc(c, stdout);

    /* Update the running column count. */
    if (c == '\n') {
        col = 0;
    } else if (c == '\t') {
        col = (col + 8) & ~7;
    } else if (c == '\b') {
        if (col != 0) col = col - 1;
    } else if (c == '\r') {
        col = 0;
    } else {
        col = col + 1;
    }
}

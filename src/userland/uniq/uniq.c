/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD uniq(1)
 *   Ported from uniq(1), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * uniq - report or filter out repeated adjacent lines.
 * Port of 2.11BSD uniq(1).
 *
 * Port-side patches:
 *  - K&R signatures -> ANSI, forward-declared
 *  - standard ANSI main(int argc, char **argv) signature (fcc binds
 *    argc → args_argc and argv → &args_argv[0], a real 4-byte char**).
 *  - freopen -> fopen into a file-scope FILE * (no freopen shim yet)
 *  - getchar -> fgetc(g_fp); '\n' or '\r' terminates a line so FGX-native
 *    CR-terminated text files work without translation
 *  - putchar -> fputc(c, stdout)
 *  - isdigit() inlined (not in fcc bindings)
 *  - printe() custom variadic helper -> direct fprintf to stderr
 *  - copyright/sccsid stripped
 *  - MVP scope: default mode only.  Dropped -u/-d/-c (print only unique,
 *    only duplicates, count), -N (skip fields), +N (skip letters).
 *    Easy to add back if useful — the algorithm is just adjacent
 *    full-line dedup.
 */
#include <stdio.h>
#include <string.h>

#define BUFSZ 512

char b1[BUFSZ];
char b2[BUFSZ];
FILE *g_fp;

int gline(char *buf);
void emit(char *buf);

int main(int argc, char **argv)
{
    char *arg;

    g_fp = stdin;

    if (argc > 1) {
        arg = argv[1];
        g_fp = fopen(arg, "r");
        if (g_fp == NULL) {
            fprintf(stderr, "uniq: cannot open %s\n", arg);
            return 1;
        }
    }

    if (gline(b1)) return 0;
    emit(b1);

    for (;;) {
        if (gline(b2)) return 0;
        if (strcmp(b1, b2) != 0) {
            emit(b2);
            strcpy(b1, b2);
        }
    }
}

int gline(char *buf)
{
    int c;
    int i;
    i = 0;
    for (;;) {
        c = fgetc(g_fp);
        if (c == EOF) {
            buf[i] = 0;
            if (i == 0) return 1;       /* clean EOF */
            return 0;                    /* line without terminator */
        }
        if (c == '\n' || c == '\r') {
            buf[i] = 0;
            return 0;
        }
        if (i < BUFSZ - 1) {
            buf[i] = c;
            i = i + 1;
        }
    }
}

void emit(char *buf)
{
    fputs(buf, stdout);
    fputc('\n', stdout);
}

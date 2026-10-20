/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD wc(1)
 *   Ported from wc(1), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * wc - line, word, and character count.
 * Port of 2.11BSD wc(1) by Bill Joy, UCB 1980.
 *
 * Port-side patches:
 *  - standard ANSI main(int argc, char **argv) signature (fcc binds
 *    argc→args_argc and argv→&args_argv[0], a real 4-byte char**).
 *  - All K&R signatures converted to ANSI prototypes; forward-declared.
 *  - getc() (not in fcc's binding table) replaced with fgetc().
 *  - %7ld width specifier dropped to %ld (fcc printf width-spec TBD;
 *    columns still print, just left-aligned with a single leading space).
 *  - Line terminator counts both '\n' (10) and '\r' (13) so FGX-native
 *    CR-terminated text files report the same line count host wc would
 *    report on the same content with LF terminators.
 *  - Multi-file accumulator (total) dropped; takes one file argument OR
 *    reads stdin when none is given (so `wc < f` and `cmd | wc` work).
 *  - copyright[]/sccsid[] blobs stripped.
 */
#include <stdio.h>

long linect, wordct, charct;
char *wd = "lwc";

void wcp(char *w, long cc, long wc, long lc);
void ipr(long num);

int main(int argc, char **argv)
{
    int i;
    int file_idx;
    int token;
    FILE *fp;
    int c;
    char *arg;

    file_idx = 1;

    if (argc > 1) {
        arg = argv[1];
        if (arg[0] == '-' && arg[1] != 0) {
            for (i = 1; arg[i] != 0; i++) {
                if (arg[i] != 'l' && arg[i] != 'w' && arg[i] != 'c') {
                    fprintf(stderr, "Usage: wc [-lwc] file\n");
                    return 1;
                }
            }
            wd = arg + 1;
            file_idx = 2;
        }
    }

    if (file_idx >= argc) {
        fp = stdin;             /* no file arg: read stdin (wc < file, cmd | wc) */
        arg = "";
    } else {
        arg = argv[file_idx];
        fp = fopen(arg, "r");
        if (fp == NULL) {
            perror(arg);
            return 1;
        }
    }

    linect = 0;
    wordct = 0;
    charct = 0;
    token = 0;
    for (;;) {
        c = fgetc(fp);
        if (c == EOF) break;
        charct++;
        if (' ' < c && c < 0177) {
            if (!token) {
                wordct++;
                token = 1;
            }
            continue;
        }
        if (c == '\n' || c == '\r') {
            linect++;
        } else if (c != ' ' && c != '\t') {
            continue;
        }
        token = 0;
    }
    wcp(wd, charct, wordct, linect);
    printf(" %s\n", arg);
    if (fp != stdin)
        fclose(fp);
    return 0;
}

void wcp(char *w, long cc, long wc, long lc)
{
    int ch;
    while (*w) {
        ch = *w++;
        if (ch == 'l') ipr(lc);
        else if (ch == 'w') ipr(wc);
        else if (ch == 'c') ipr(cc);
    }
}

void ipr(long num)
{
    printf(" %ld", num);
}

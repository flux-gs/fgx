/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD uname(1)
 *   Ported from uname(1), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * uname - print system information.  Port of 2.11BSD uname(1) (UCB 1993).
 *
 * 2.11BSD's uname pulls each field from sysctl (KERN_OSTYPE/HOSTNAME/
 * OSRELEASE/VERSION, HW_MACHINE).  FGX has no uname(2)/sysctl, so:
 *   -s sysname  : constant "BSD"
 *   -m machine  : constant "65816 (Apple IIgs)"
 *   -n nodename : contents of /etc/hostname
 *   -r release  : contents of /etc/version
 *   -v version  : contents of /etc/build   (branch + build date; the
 *                 newvers.sh/KERN_VERSION analog, written by build.sh)
 *   -a          : all fields, space-separated, in BSD order  s n r v m
 * Default (no flags) prints -s only.  Unknown flags are ignored.
 *
 * Port-side notes (fcc idiom, per fold.c / wc.c):
 *  - ANSI main(int argc, char **argv); argv[i] auto-bound by fcc.
 *  - file fields read via fopen + fgetc loop (putchar/fread-shim avoided).
 *  - no compound assignment / switch-on-char; plain if/else + while loops.
 */
#include <stdio.h>

#define SYSNAME "BSD"
#define MACHINE "65816 (Apple IIgs)"

int first;
char fbuf[128];

/* Emit the inter-field separator: a space before every field but the first. */
void sep(void)
{
    if (first == 0)
        printf(" ");
    first = 0;
}

/* Print a constant field. */
void emit(char *s)
{
    sep();
    printf("%s", s);
}

/* Print the first line of `path` (newline-stripped); "unknown" if absent. */
void emitfile(char *path)
{
    FILE *fp;
    int c;
    int k;

    fp = fopen(path, "r");
    if (fp == 0) {
        emit("unknown");
        return;
    }
    k = 0;
    while ((c = fgetc(fp)) != EOF) {
        if (c == '\n' || c == '\r')
            break;
        if (k < 127) {
            fbuf[k] = c;
            k = k + 1;
        }
    }
    fclose(fp);
    fbuf[k] = 0;
    if (k == 0) {
        emit("unknown");
        return;
    }
    emit(fbuf);
}

int main(int argc, char **argv)
{
    int sflag, nflag, rflag, vflag, mflag;
    int i, j;
    char *a;

    sflag = 0;
    nflag = 0;
    rflag = 0;
    vflag = 0;
    mflag = 0;
    first = 1;

    i = 1;
    while (i < argc) {
        a = argv[i];
        if (a[0] == '-') {
            j = 1;
            while (a[j] != 0) {
                if (a[j] == 'a') {
                    sflag = 1;
                    nflag = 1;
                    rflag = 1;
                    vflag = 1;
                    mflag = 1;
                } else if (a[j] == 's') {
                    sflag = 1;
                } else if (a[j] == 'n') {
                    nflag = 1;
                } else if (a[j] == 'r') {
                    rflag = 1;
                } else if (a[j] == 'v') {
                    vflag = 1;
                } else if (a[j] == 'm') {
                    mflag = 1;
                }
                j = j + 1;
            }
        }
        i = i + 1;
    }

    if (sflag == 0 && nflag == 0 && rflag == 0 && vflag == 0 && mflag == 0)
        sflag = 1;

    if (sflag)
        emit(SYSNAME);
    if (nflag)
        emitfile("/etc/hostname");
    if (rflag)
        emitfile("/etc/version");
    if (vflag)
        emitfile("/etc/build");
    if (mflag)
        emit(MACHINE);
    printf("\n");
    return 0;
}

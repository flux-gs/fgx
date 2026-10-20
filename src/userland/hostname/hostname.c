/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD hostname(1)
 *   Ported from hostname(1), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * hostname - print the system hostname.  Port of 2.11BSD hostname(1).
 *
 * FGX has no sethostname(2); the name lives in /etc/hostname.  This v1
 * is print-only (a name argument, which BSD would use to set, is ignored).
 * Reads the first line of /etc/hostname; prints "unknown" if absent.
 */
#include <stdio.h>

char buf[128];

int main(int argc, char **argv)
{
    FILE *fp;
    int c;
    int k;

    fp = fopen("/etc/hostname", "r");
    if (fp == 0) {
        printf("unknown\n");
        return 1;
    }
    k = 0;
    while ((c = fgetc(fp)) != EOF) {
        if (c == '\n' || c == '\r')
            break;
        if (k < 127) {
            buf[k] = c;
            k = k + 1;
        }
    }
    fclose(fp);
    buf[k] = 0;
    printf("%s\n", buf);
    return 0;
}

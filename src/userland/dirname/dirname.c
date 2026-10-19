/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD dirname(1)
 *   Ported from dirname(1), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * dirname - strip the last component from a path.  Port of 2.11BSD dirname(1).
 *
 *   dirname string
 *
 *   "/usr/bin/cat" -> "/usr/bin"
 *   "/foo"         -> "/"
 *   "foo"          -> "."
 *
 * Port-side: hand-rolled scans (no string.h), locals up top (fcc C89-ish),
 * a found-flag instead of a negative sentinel (fcc int comparisons).
 */
#include <stdio.h>

char out[128];

int main(int argc, char **argv)
{
    char *p;
    int i, last, found, k;

    if (argc < 2) {
        printf("usage: dirname string\n");
        return 1;
    }
    p = argv[1];

    found = 0;
    last = 0;
    i = 0;
    while (p[i] != 0) {
        if (p[i] == '/') {
            last = i;
            found = 1;
        }
        i = i + 1;
    }

    if (found == 0) {
        printf(".\n");
        return 0;
    }
    if (last == 0) {
        printf("/\n");
        return 0;
    }

    k = 0;
    while (k < last && k < 127) {
        out[k] = p[k];
        k = k + 1;
    }
    out[k] = 0;
    printf("%s\n", out);
    return 0;
}

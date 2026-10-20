/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD basename(1)
 *   Ported from basename(1), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * basename - strip directory (and optional suffix) from a path.
 * Port of 2.11BSD basename(1).
 *
 *   basename string [suffix]
 *
 * v1 MVP: no trailing-slash collapsing (basename "/a/b/" -> "" not "b");
 * matches the classic terse behavior, sufficient for "basename /a/b/c".
 * Port-side: hand-rolled scans (no string.h); all locals declared up top
 * (fcc is C89-ish); no break/compound-assign per fold.c/uname.c idiom.
 */
#include <stdio.h>

char out[128];

int main(int argc, char **argv)
{
    char *p;
    char *suf;
    int i, n, last, sl, match, j;

    if (argc < 2) {
        printf("usage: basename string [suffix]\n");
        return 1;
    }
    p = argv[1];

    /* last = index just past the final '/' (0 if none). */
    last = 0;
    i = 0;
    while (p[i] != 0) {
        if (p[i] == '/')
            last = i + 1;
        i = i + 1;
    }

    /* copy the trailing component into out. */
    n = 0;
    i = last;
    while (p[i] != 0 && n < 127) {
        out[n] = p[i];
        n = n + 1;
        i = i + 1;
    }
    out[n] = 0;

    /* strip suffix if supplied, present, and not the whole name. */
    if (argc > 2) {
        suf = argv[2];
        sl = 0;
        while (suf[sl] != 0)
            sl = sl + 1;
        if (sl > 0 && sl < n) {
            match = 1;
            j = 0;
            while (j < sl) {
                if (out[n - sl + j] != suf[j])
                    match = 0;
                j = j + 1;
            }
            if (match)
                out[n - sl] = 0;
        }
    }

    printf("%s\n", out);
    return 0;
}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD yes(1)
 *   Ported from yes(1), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * yes - print 'y' (or argv[1]) repeatedly.
 * Port of 2.11BSD yes(1) by Bill Joy, UCB 1980.
 *
 * Port-side patch: original `for (;;)` (infinite) replaced with a
 * 5-iteration counted loop so the binary terminates without relying
 * on shell-pipeline SIGPIPE delivery (FGX shell pipeline behavior
 * around SIGPIPE is not yet specified).
 */
#include <stdio.h>

int main(int argc, char **argv)
{
    char *s;
    int i;
    s = (argc > 1) ? argv[1] : "y";
    for (i = 0; i < 5; i++) {
        printf("%s\n", s);
    }
    return 0;
}

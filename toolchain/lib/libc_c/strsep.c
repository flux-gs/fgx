/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/src/lib/libc/string/strsep.c
 *   Ported from usr/src/lib/libc/string/strsep.c, 2.11BSD.  Original work:
 *   Copyright (c) 1990, 1993 The Regents of the University of California.
 *   All rights reserved.
 */
/* strsep(3).  UFS 2.1, wanted by fstab(3) and so by fsck(8).
 *
 * ONE FUNCTION PER FILE, WHICH IS UPSTREAM'S LAYOUT AND ALSO A SIZE
 * REQUIREMENT HERE.  The libc pile is dead-stripped per tool at FILE
 * granularity, so a function appended to string.c rides into every binary that
 * calls strlen.  These three first landed there and pushed toolchain/tests/M37
 * vreclaim's single 64 KB code segment over the limit -- a fixture that calls
 * no string function of this kind at all.
 */

/* Next token from *stringp, tokens being POSSIBLY-EMPTY strings separated by
 * characters from delim.  That empty-token property is the whole difference
 * from strtok and is what the colon-separated fstab form needs: `a::b' has
 * three fields, and strtok would report two. */
char *strsep(char **stringp, char *delim)
{
    char *s;
    char *spanp;
    int   c, sc;
    char *tok;

    if ((s = *stringp) == (char *)0)
        return ((char *)0);
    for (tok = s;;) {
        c = *s++;
        spanp = delim;
        do {
            if ((sc = *spanp++) == c) {
                if (c == 0)
                    s = (char *)0;
                else
                    s[-1] = 0;
                *stringp = s;
                return (tok);
            }
        } while (sc != 0);
    }
    /* NOTREACHED */
}

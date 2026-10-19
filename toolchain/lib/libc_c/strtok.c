/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/src/lib/libc/string/strtok.c
 *   Ported from usr/src/lib/libc/string/strtok.c, 2.11BSD.  Original work:
 *   Copyright (c) 1990, 1993 The Regents of the University of California.
 *   All rights reserved.
 */
/* strtok(3).  UFS 2.1, wanted by fstab(3) and so by fsck(8).
 *
 * ONE FUNCTION PER FILE, WHICH IS UPSTREAM'S LAYOUT AND ALSO A SIZE
 * REQUIREMENT HERE.  The libc pile is dead-stripped per tool at FILE
 * granularity, so a function appended to string.c rides into every binary that
 * calls strlen.  These three first landed there and pushed toolchain/tests/M37
 * vreclaim's single 64 KB code segment over the limit -- a fixture that calls
 * no string function of this kind at all.
 */

/* Next token, skipping leading delimiters and collapsing runs of them.  The
 * `last' static is upstream's and is why strtok is not reentrant. */
char *strtok(char *s, char *delim)
{
    char       *spanp;
    int         c, sc;
    char       *tok;
    static char *last;

    if (s == (char *)0 && (s = last) == (char *)0)
        return ((char *)0);

    /* Skip (span) leading delimiters. */
cont:
    c = *s++;
    for (spanp = delim; (sc = *spanp++) != 0;) {
        if (c == sc)
            goto cont;
    }
    if (c == 0) {                       /* no non-delimiter characters */
        last = (char *)0;
        return ((char *)0);
    }
    tok = s - 1;

    /* Scan the token, terminating it at the first delimiter and remembering
     * where to resume.  A NUL delimiter ends the whole string. */
    for (;;) {
        c = *s++;
        spanp = delim;
        do {
            if ((sc = *spanp++) == c) {
                if (c == 0)
                    s = (char *)0;
                else
                    s[-1] = 0;
                last = s;
                return (tok);
            }
        } while (sc != 0);
    }
    /* NOTREACHED */
}

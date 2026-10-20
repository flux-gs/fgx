/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/src/lib/libc/string/strpbrk.c
 *   Ported from usr/src/lib/libc/string/strpbrk.c, 2.11BSD.  Original work:
 *   Copyright (c) 1990, 1993 The Regents of the University of California.
 *   All rights reserved.
 */
/* strpbrk(3).  UFS 2.1, wanted by fstab(3) and so by fsck(8).
 *
 * ONE FUNCTION PER FILE, WHICH IS UPSTREAM'S LAYOUT AND ALSO A SIZE
 * REQUIREMENT HERE.  The libc pile is dead-stripped per tool at FILE
 * granularity, so a function appended to string.c rides into every binary that
 * calls strlen.  These three first landed there and pushed toolchain/tests/M37
 * vreclaim's single 64 KB code segment over the limit -- a fixture that calls
 * no string function of this kind at all.
 */

/* Find the first occurrence in s1 of a character in s2 (excluding NUL). */
char *strpbrk(char *s1, char *s2)
{
    char *scanp;
    int   c, sc;

    while ((c = *s1++) != 0) {
        for (scanp = s2; (sc = *scanp++) != 0;)
            if (sc == c)
                return (s1 - 1);
    }
    return ((char *)0);
}

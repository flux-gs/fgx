/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/string/strstr.c
 *   Original work: Copyright (c) 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 */
/* strstr(3).  UFS 2.6, wanted by mount(8)'s option parsing (`strstr(optbuf,
 * "union")').
 *
 * ONE FUNCTION PER FILE, which is strsep.c's rule and its reason: the libc
 * pile is dead-stripped per tool at FILE granularity, so a function appended
 * to string.c rides into every binary that calls strlen.
 *
 * VERBATIM but for the K&R-to-prototype header and NULL spelled as 0 -- this
 * pile has no <stddef.h> and the cast is the same value.
 */
#include <string.h>

char *
strstr(s, find)
register char *s;
register char *find;
{
    register char c;
    char   sc;
    int    len;

    if ((c = *find++) != 0) {
        len = strlen(find);
        do {
            do {
                if ((sc = *s++) == 0)
                    return ((char *)0);
            } while (sc != c);
        } while (strncmp(s, find, len) != 0);
        s--;
    }
    return ((char *)s);
}

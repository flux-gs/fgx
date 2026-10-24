/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* vsnprintf.c -- vsnprintf(3) and snprintf(3).
 *
 * FGX-Provenance: netbsd-0-9 lib/libc/stdio/vsnprintf.c
 *   Interface from vsnprintf.c 5.2 (Berkeley) 2/5/91, vendored at
 *   vendor/netbsd-0-9/lib/libc/stdio/vsnprintf.c.  Original work:
 *   Copyright (c) 1990 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * The INTERFACE is netbsd-0-9's: at most sz - 1 characters and a NUL are
 * stored, and the answer is the length the whole output would have had.
 * The body is 2.11BSD sprintf.c's: an _IOSTRG FILE over the buffer, its
 * count the room, for _doprnt.  What does not fit goes to _flsbuf, which
 * drops a full string's characters (flsbuf.c), and _doprnt counts it all.
 *
 * Its own member, so that only its callers link it. */
int vsnprintf(char *buf, int sz, char *fmt, char *ap)
{
    FILE f;
    int r;

    f._flag = _IOWRT+_IOSTRG;
    f._ptr = buf;
    f._cnt = (sz > 0) ? sz - 1 : 0;
    r = _doprnt(fmt, ap, &f);
    if (sz > 0)
        *f._ptr = 0;
    return r;
}

int snprintf(char *buf, int sz, char *fmt, ...)
{
    va_list ap;
    int r;

    va_start(ap, fmt);
    r = vsnprintf(buf, sz, fmt, ap);
    va_end(ap);
    return r;
}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* vsnprintf.c -- vsnprintf(3).
 *
 * FGX-Provenance: netbsd-0-9 lib/libc/stdio/vsnprintf.c
 *   Interface from vsnprintf.c 5.2 (Berkeley) 2/5/91, vendored at
 *   vendor/netbsd-0-9/lib/libc/stdio/vsnprintf.c.  Original work:
 *   Copyright (c) 1990 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * snprintf over a caller-built va_list, with netbsd-0-9's interface: at most
 * sz - 1 characters and a NUL are
 * stored, and the answer is the length the whole output would have had, as
 * snprintf's is.
 *
 * ITS OWN MEMBER, AFTER printf.c, because it drives printf.c's buffer-mode
 * engine through that member's file-scope statics, which the one-TU pile
 * shares.  In printf.c it would be linked by every printf user, and tcsh's
 * libc bank has no room for it; here only its callers carry it. */
int vsnprintf(char *buf, int sz, char *fmt, char *ap)
{
    int r;

    __lc_pf_mode = 1; __lc_pf_out = buf;
    __lc_pf_lim = (sz > 0) ? (unsigned)(sz - 1) : 0;
    __lc_pf_n = 0;
    r = __lc_vpf(fmt, ap);
    if (sz > 0)
        buf[(__lc_pf_n < __lc_pf_lim) ? __lc_pf_n : __lc_pf_lim] = 0;
    return r;
}

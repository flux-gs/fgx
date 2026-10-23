/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* sprintf.c -- sprintf(3) and vsprintf(3): the formatter (doprnt.c) into a
 * caller's buffer, unbounded.  2.11BSD's sprintf builds a FILE flagged
 * _IOSTRG on the string; the engine's buffer mode is the same thing without
 * the FILE, and is what snprintf (vsnprintf.c) needs for its bound. */
int sprintf(char *buf, char *fmt, ...)
{
    va_list ap;
    int r;

    va_start(ap, fmt);
    __lc_pf_mode = 1; __lc_pf_out = buf;
    __lc_pf_lim = 0xFFFF; __lc_pf_n = 0;    /* unbounded (sprintf contract) */
    r = __lc_vpf(fmt, ap);
    buf[__lc_pf_n] = 0;
    va_end(ap);
    return r;
}

/* vsprintf: sprintf over a caller-built va_list (curses printw/_sprintw —
 * the 4.3BSD `&args` idiom is byte-identical to our va_list under the
 * uniform R-to-L stack ABI). */
int vsprintf(char *buf, char *fmt, char *ap)
{
    int r;

    __lc_pf_mode = 1; __lc_pf_out = buf;
    __lc_pf_lim = 0xFFFF; __lc_pf_n = 0;    /* unbounded (sprintf contract) */
    r = __lc_vpf(fmt, ap);
    buf[__lc_pf_n] = 0;
    return r;
}


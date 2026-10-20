/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/ttychars.h
 *   Ported from usr/sys/h/ttychars.h, 2.11BSD.
 *   Original work:
 *   Copyright (c) 1982, 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* ttychars.h -- the fourteen special characters, and their defaults.
 *
 * Verbatim.  CTRL(c) is upstream's ('c'&037) -- it takes a LETTER, not an
 * expression, which is why CQUIT is written 034 rather than CTRL(\).
 */
#ifndef _TTYCHARS_H_
#define _TTYCHARS_H_

struct ttychars {
    char    tc_erase;       /* erase last character */
    char    tc_kill;        /* erase entire line */
    char    tc_intrc;       /* interrupt */
    char    tc_quitc;       /* quit */
    char    tc_startc;      /* start output */
    char    tc_stopc;       /* stop output */
    char    tc_eofc;        /* end-of-file */
    char    tc_brkc;        /* input delimiter (like nl) */
    char    tc_suspc;       /* stop process signal */
    char    tc_dsuspc;      /* delayed stop process signal */
    char    tc_rprntc;      /* reprint line */
    char    tc_flushc;      /* flush output (toggles) */
    char    tc_werasc;      /* word erase */
    char    tc_lnextc;      /* literal next character */
};

#define CTRL(c)         ('c'&037)
#define _POSIX_VDISABLE ((unsigned char)'\377')
#define CCEQ(val,c)     (c == val ? val != _POSIX_VDISABLE : 0)

/* default special characters */
#define CERASE  0177
#define CKILL   CTRL(u)
#define CINTR   CTRL(c)
#define CQUIT   034             /* FS, ^\ */
#define CSTART  CTRL(q)
#define CSTOP   CTRL(s)
#define CEOF    CTRL(d)
#define CEOT    CEOF
#define CBRK    _POSIX_VDISABLE
#define CSUSP   CTRL(z)
#define CDSUSP  CTRL(y)
#define CRPRNT  CTRL(r)
#define CFLUSH  CTRL(o)
#define CWERASE CTRL(w)
#define CLNEXT  CTRL(v)

#endif /* _TTYCHARS_H_ */

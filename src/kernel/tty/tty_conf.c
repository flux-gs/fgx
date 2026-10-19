/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/sys/tty_conf.c
 *   Ported from usr/sys/sys/tty_conf.c and usr/sys/sys/subr_xxx.c (nodev,
 *   nulldev), 2.11BSD.
 *   Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* tty_conf.c -- the line-discipline switch.  T2.1 of apple/fgx#108.
 *
 * TEN SLOTS AND FIVE ROWS, upstream's shape exactly, even though FGX fills
 * one row and three slots of it.  The shape is the point: every BSD tty
 * driver's read is two lines -- find my `struct tty *', then
 * `(*linesw[tp->t_line].l_read)(tp, uio, flag)' -- and that only works if the
 * table is indexed the way upstream indexes it.  A table trimmed to what is
 * filled today would have to be renumbered the day a discipline arrives, and
 * t_line values are written into ttys by userland ioctl.
 *
 * ROWS 1, 3 and 4 ARE nodev BECAUSE UPSTREAM LEAVES THEM THAT WAY when their
 * drivers are unconfigured -- `#if NBK > 0 ... #else nodev, nodev, ...'.  FGX
 * has no Berkeley-net, tablet or SLIP discipline, so the #else arm is the
 * whole row.  That is a port of upstream's own fallback, not a stub of ours.
 *
 *============================================================================
 * ROWS 0 AND 2 POINT AT ADAPTERS, AND THAT IS T2's WHOLE BARGAIN.
 *
 * The real routines -- ttyopen, ttread, ttwrite, ttyinput, ttstart, ttymodem
 * -- are tty.c, which is T3.  Relocating the 790 lines of core-bank discipline
 * they replace would be paying twice, because T3 deletes them.  So the rows
 * name `ttyadapt_*' routines that will be REPLACED WHOLE at T3, when linesw[0]
 * and linesw[2] repoint at the ported originals and this file loses the
 * adapters.
 *
 * WHAT THE ADAPTERS DO AT T2.1 IS NOTHING, AND THEY SAY SO by returning
 * distinct values rather than a shared zero.  tty_probe drives every slot and
 * asserts WHICH adapter answered, so the table's indexing is under test even
 * though its bodies are not: a row copied one slot out of line -- the failure
 * this layout invites -- lands on the wrong adapter and the probe names it.
 * T2.2 gives them bodies, which is when `l_read'/`l_write' start unpacking a
 * uio into today's per-byte loop.
 */

#include "ttyparam.h"
#include "clist.h"
#include "tty.h"
#include "conf.h"

/*
 * Error and no-op device routines.  usr/sys/sys/subr_xxx.c.
 */
nodev()
{
    return (ENODEV);
}

/*
 * Null routine; placed in insignificant entries
 * in the bdevsw and cdevsw tables.
 */
nulldev()
{
    return (0);
}

/* THE T2.1 ADAPTERS.  Each returns its own slot's number so a misindexed row
 * is a wrong answer rather than a plausible one -- see the head note.  The
 * values are negative so they cannot be confused with the errno a real
 * routine returns, and so a caller that mistakes one for a byte count sees a
 * short read rather than a long one. */
#define TTADAPT_READ    (-3)
#define TTADAPT_WRITE   (-4)
#define TTADAPT_RINT    (-6)
#define TTADAPT_START   (-9)

ttyadapt_read()   { return (TTADAPT_READ); }
ttyadapt_write()  { return (TTADAPT_WRITE); }
ttyadapt_rint()   { return (TTADAPT_RINT); }
ttyadapt_start()  { return (TTADAPT_START); }
/* ttyadapt_modem AND ttyadapt_open STOOD HERE.  T4's repoints put the real
 * `ttymodem' in `l_modem' (increment 1) and the real `ttyopen' in `l_open'
 * (increment 2) for both real rows -- which is the reason tty.c:835 gives for
 * having ported ttymodem at all: "the linesw slot it fills is what T4's
 * repoint needs to find already here".
 *
 * NEITHER SLOT HAD A CALLER WHILE IT WAS AN ADAPTER, and l_open's absence was
 * the more expensive one: TS_ISOPEN is set by `ttyopen' and by nothing else,
 * so no line in this kernel had it, and every test of it -- ttread's,
 * ttwrite's, and `ttymodem's whole hangup arm -- was reading a bit that could
 * not be 1.  `ptsopen' is l_open's first caller (2.11BSD tty_pty.c:88) and
 * `ptcopen'/`ptcclose' are l_modem's (:214, :228).
 *
 * ttyadapt_close WENT WITH THEM at increment 3, and the three repoints are one
 * story: `ptsopen' calls l_open, `ptsclose' calls l_close, and `ptcopen' and
 * `ptcclose' bracket the pair with l_modem.  A line that opens through the
 * discipline must close through it, or TS_ISOPEN never comes down and one
 * session's unread input is the next session's first read.
 *
 * `l_close' IS `ttylclose', NOT `ttyclose', and the difference is load-bearing:
 * `ttylclose' takes the DISCIPLINE off the line, `ttyclose' cleans the LINE.
 * `ptsclose' calls both in that order, which is why the row names only the
 * first -- the second is the DRIVER's call and is made at the driver's door
 * (kc_ttclose, tty_dev.c). */

extern int ttyopen();           /* tty.c -- the real open, and TS_ISOPEN */
extern int ttylclose();         /* tty.c -- the real discipline teardown */
extern int ttymodem();          /* tty.c -- the real carrier handler */

/*
 * Do nothing specific version of line
 * discipline specific ioctl command.
 */
/*ARGSUSED*/
nullioctl(tp, cmd, data, flags)
    struct tty *tp;
    unsigned cmd;
    char *data;
    int flags;
{
    return (-1);
}

/* THE FIRST TWO SLOTS THAT ARE NOT ADAPTERS -- apple/fgx#108 T3 stage 3.
 * `l_write' is `ttwrite' and `l_start' is `ttstart', the ported originals, in
 * both standard rows.  This is what T2.1's bargain was for: the table was
 * built to upstream's shape so that a slot could be repointed without
 * renumbering anything, and these two are the first to collect on it.
 *
 * THE OTHER EIGHT ARE STILL ADAPTERS and stay that way until stages 4 and
 * beyond -- l_read, l_rint and the open/close/modem set move with the INPUT
 * side.  A row half-repointed is exactly the two-truths shape the campaign
 * warns about ONLY when both halves describe the same state; the write queue
 * and the input queue are different queues, which is why the sides can move
 * separately at all. */
extern int ttwrite();
extern int ttstart();

struct linesw linesw[] =
{
    ttyopen, ttylclose, ttread, ttwrite, nullioctl,
    ttyinput, nodev, nulldev, ttstart, ttymodem,
                                                    /* 0- OTTYDISC */
    nodev, nodev, nodev, nodev, nodev,
    nodev, nodev, nodev, nodev, nodev,              /* 1- NETLDISC */

    ttyopen, ttylclose, ttread, ttwrite, nullioctl,
    ttyinput, nodev, nulldev, ttstart, ttymodem,
                                                    /* 2- NTTYDISC */
    nodev, nodev, nodev, nodev, nodev,
    nodev, nodev, nodev, nodev, nodev,              /* 3- TABLDISC */

    nodev, nodev, nodev, nodev, nodev,
    nodev, nodev, nodev, nodev, nodev,              /* 4- SLIPDISC */
};

int nldisp = sizeof (linesw) / sizeof (linesw[0]);

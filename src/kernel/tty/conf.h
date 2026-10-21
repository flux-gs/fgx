/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/conf.h
 *   Ported from usr/sys/h/conf.h, 2.11BSD.
 *   Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* conf.h -- the device and line-discipline switches.
 *
 * `struct linesw' has its reader at T2.1: tty_conf.c defines the table and
 * clist_probe's sibling drives it.  `struct cdevsw' does NOT yet -- FGX's
 * character-device switch is the runtime registry in include/chardev.s, and
 * T2.2 is what reshapes its op vector to these signatures.  It is carried now
 * for the reason struct tty was at T1: the definition emits no bytes, and
 * porting the drivers against half a shape later costs more than having it
 * early.
 *
 * `struct bdevsw' is in src/kernel/vfs/bio_strategy.c, the one file that
 * fills and calls it: the block switch lives in vfs.mod with the buffer cache,
 * and this header is the tty bank's.
 */
#ifndef _CONF_H_
#define _CONF_H_

/*
 * Character device switch.
 */
struct cdevsw {
    int         (*d_open)();
    int         (*d_close)();
    int         (*d_read)();
    int         (*d_write)();
    int         (*d_ioctl)();
    int         (*d_stop)();
    struct tty  *d_ttys;
    int         (*d_select)();
    int         (*d_strategy)();
};

/*
 * tty line control switch.
 */
struct linesw {
    int (*l_open)();
    int (*l_close)();
    int (*l_read)();
    int (*l_write)();
    int (*l_ioctl)();
    int (*l_rint)();
    int (*l_rend)();
    int (*l_meta)();
    int (*l_start)();
    int (*l_modem)();
};

extern struct linesw linesw[];
extern int nldisp;

/* Line-discipline numbers, from usr/sys/h/ioctl.h.  Only OTTYDISC has a
 * filled row; the rest are nodev, exactly as upstream leaves them when their
 * drivers are not configured. */
#define OTTYDISC    0       /* old, v7 std tty driver */
#define NETLDISC    1       /* line discip for berk net */
#define NTTYDISC    2       /* new tty discipline */
#define TABLDISC    3       /* tablet discipline */
#define SLIPDISC    4       /* serial IP discipline */

#endif /* _CONF_H_ */

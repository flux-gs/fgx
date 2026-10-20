/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* daemon.c -- daemon(3): become a background daemon.
 *
 * FGX-Provenance: 2.11BSD lib/libc/gen/daemon.c
 *   Ported from daemon(3), 2.11BSD (8.1.1 (2.11BSD GTE) 2/3/95).  Original work:
 *   Copyright (c) 1990, 1993
 *   The Regents of the University of California.  All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * daemon(nochdir, noclose) -- become a background daemon.
 *
 * Upstream is four steps and nothing else: fork and let the parent _exit so the
 * child is reparented to init; give up the controlling terminal; chdir("/") so
 * the daemon holds no directory a filesystem cannot be unmounted under; and
 * point 0/1/2 at /dev/null so a stray printf cannot reach a console.
 *
 * syslogd(8) calls daemon(0, 0) -- both steps wanted.
 *
 * The fork is upstream's: the parent _exits, the child carries on, and the
 * invoker's shell or /etc/rc gets control back.  FGX's fork runs the parent
 * again once the child first sleeps interruptibly (the kernel's image groups,
 * src/kernel/process.s), which every daemon's main loop does.
 *
 * THE DETACH IS THE ONE PART THAT IS NOT UPSTREAM'S CODE.  Upstream writes
 *
 *      if ((fd = open(_PATH_TTY, O_RDWR)) >= 0) {
 *              ioctl(fd, TIOCNOTTY, 0);
 *              close(fd);
 *      }
 *
 * and /dev/tty is a node with no driver behind it in FGX: `("tty", 8)' is in
 * gen.py's DEV_NODES so the inode exists on the volume, and no module
 * registers device 8, so the open fails ENXIO and the ioctl never runs.
 *
 * What FGX has instead is a TIOCNOTTY that does not care WHICH tty descriptor
 * it arrives on.  `src/kernel/syscall.s' @si_dtch says so, and the reason is
 * upstream's own handler:
 *
 *      if (cmd == TIOCNOTTY) {
 *              u.u_ttyp = 0; u.u_ttyd = 0; u.u_procp->p_pgrp = 0; return (0);
 *      }
 *                      -- vendor/2.11BSD/usr/sys/sys/tty_tty.c:58-62
 *
 * That handler reads nothing from the tty and writes nothing to it: it is three
 * assignments to the CALLING PROCESS.  Opening /dev/tty upstream is how a
 * process gets a descriptor to a tty it is known to own; it is not an argument
 * to the operation.  So this walks 0, 1, 2 for one that is a terminal and
 * detaches through that, which reaches the same three assignments.
 *
 * A daemon started with its standard descriptors already redirected has no tty
 * among them and no detach happens.  It also has no controlling terminal to
 * give up in that case -- FGX binds one at a tty open, `src/kernel/ttyv.s'
 * _Se_TtyOpen, and a process that never opened a tty never acquired one.  The
 * case this cannot serve is a process holding a ctty acquired before its
 * descriptors were redirected away from it; nothing in FGX does that today, and
 * the honest fix when something does is a TIOCNOTTY road that needs no
 * descriptor, not a scan of more of them.
 */

int daemon(int nochdir, int noclose)
{
    int fd;
    int i;

    switch (fork()) {
    case -1:
        return (-1);
    case 0:
        break;
    default:
        _exit(0);
    }

    for (i = 0; i < 3; i++)
        if (isatty(i)) {
            (void)ioctl(i, TIOCNOTTY, (char *)0);
            break;
        }

    if (!nochdir)
        (void)chdir("/");

    if (!noclose && (fd = open("/dev/null", O_RDWR, 0)) != -1) {
        (void)dup2(fd, 0);
        (void)dup2(fd, 1);
        (void)dup2(fd, 2);
        if (fd > 2)
            (void)close(fd);
    }
    return (0);
}

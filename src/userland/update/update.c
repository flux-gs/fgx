/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 1987, 1990, 1993
 *   The Regents of the University of California.  All rights reserved.
 *
 * FGX-Provenance: 2.11BSD update(8)
 *   Ported from update.c 8.1.1 (2.11BSD) 1999/10/24, vendored at
 *   vendor/2.11BSD/usr/usr.sbin/update/update.c.  UCB notice retained per the
 *   BSD license; FGX changes are BSD-2-Clause (see LICENSE /
 *   docs/PROVENANCE.md).
 *
 * update - call sync(2) every thirty seconds, forever.
 *
 * WHAT IT IS FOR.  A dirty buffer reaches the disk when something needs the
 * buffer back, and a superblock when its allocation batch fills.  Neither is a
 * clock, so a machine that is merely RUNNING never writes back what it changed:
 * the boot itself allocates one block for /etc/utmp, and a volume powered off
 * at the prompt records that block as free while an inode owns it.  This is the
 * clock.  update.8's whole specification is one sentence -- "executes the
 * sync(2) primitive every 30 seconds" -- and the interval is upstream's.
 *
 * UPSTREAM'S TEXT, WITH NO DELTA: daemon(0, 0), a repeating 30-second
 * setitimer(ITIMER_REAL) and sigsuspend with sync() as the SIGALRM handler.
 * FGX's ITIMER_REAL counts whole seconds, and so does upstream's (2.11BSD
 * kern_time.c rounds any microseconds up to the next second), so the period is
 * the one upstream gets.
 *
 * Upstream's 4.3BSD-Reno arm also opens the directories in pathnames.h's
 * `fillst' to hold them in the buffer cache.  2.11BSD's does not, and neither
 * does this.
 */
#if	!defined(lint) && defined(DOSCCS)
static char copyright[] =
"@(#) Copyright (c) 1987, 1990, 1993\n\
	The Regents of the University of California.  All rights reserved.\n";

static char sccsid[] = "@(#)update.c	8.1.1 (2.11BSD) 1999/10/24";
#endif

#include <sys/time.h>
#include <signal.h>
#include <stdio.h>

main()
{
	struct itimerval value;
	sigset_t set;
	void mysync();

	daemon(0, 0);

	(void)signal(SIGALRM, mysync);

	value.it_interval.tv_sec = 30;
	value.it_interval.tv_usec = 0;
	value.it_value = value.it_interval;
	if (setitimer(ITIMER_REAL, &value, NULL)) {
		perror("update: setitimer");
		exit(1);
	}

	(void)sigemptyset(&set);
	for (;;)
		sigsuspend(&set);
	/* NOTREACHED */
}

void
mysync()
{
	(void)sync();
}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/gen/siglist.c
 *   Original work: Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 */
/* sys_siglist[] -- the signal names, indexed by signal number.  UFS 2.6.
 *
 * WANTED BY mount(8), which reports a mount_<type> child that died on a signal
 * rather than exiting: `errx(1, "%s: %s", ..., sys_siglist[WTERMSIG(status)])'.
 * Every BSD tool that waits on a child reaches for it eventually.
 *
 * VERBATIM.  A MEMBER OF ITS OWN, which is strsep.c's rule -- the libc pile is
 * dead-stripped at FILE granularity and this is 33 pointers plus their
 * strings, which nothing that merely calls kill(2) should have to carry.
 *
 * NSIG SIZES IT AND NSIG IS 32 HERE, one past the largest SIG* as signal.h
 * requires; the table's own last entry is SIGUSR2 at 31.  A signal added to
 * signal.h without a row here would leave a null pointer at that index, which
 * is the hazard sys_siglist(3) warns about in as many words: "it should be
 * checked because new signals may be added to the system before they are
 * added to the table."
 */
#include <signal.h>

char	*sys_siglist[NSIG] = {
	"Signal 0",
	"Hangup",			/* SIGHUP */
	"Interrupt",			/* SIGINT */
	"Quit",				/* SIGQUIT */
	"Illegal instruction",		/* SIGILL */
	"Trace/BPT trap",		/* SIGTRAP */
	"IOT trap",			/* SIGIOT */
	"EMT trap",			/* SIGEMT */
	"Floating point exception",	/* SIGFPE */
	"Killed",			/* SIGKILL */
	"Bus error",			/* SIGBUS */
	"Segmentation fault",		/* SIGSEGV */
	"Bad system call",		/* SIGSYS */
	"Broken pipe",			/* SIGPIPE */
	"Alarm clock",			/* SIGALRM */
	"Terminated",			/* SIGTERM */
	"Urgent I/O condition",		/* SIGURG */
	"Stopped (signal)",		/* SIGSTOP */
	"Stopped",			/* SIGTSTP */
	"Continued",			/* SIGCONT */
	"Child exited",			/* SIGCHLD */
	"Stopped (tty input)",		/* SIGTTIN */
	"Stopped (tty output)",		/* SIGTTOU */
	"I/O possible",			/* SIGIO */
	"Cputime limit exceeded",	/* SIGXCPU */
	"Filesize limit exceeded",	/* SIGXFSZ */
	"Virtual timer expired",	/* SIGVTALRM */
	"Profiling timer expired",	/* SIGPROF */
	"Window size changes",		/* SIGWINCH */
	"Signal 29",
	"User defined signal 1",	/* SIGUSR1 */
	"User defined signal 2"		/* SIGUSR2 */
};

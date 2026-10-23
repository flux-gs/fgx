/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/gen/popen.c
 *   Original work: popen.c 5.15.1 (2.11BSD) 1999/10/24,
 *	Copyright (c) 1988
 *	The Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
static int *pids;

FILE *
popen(program, type)
	char *program;
	register char *type;
{
	register FILE *iop;
	int pdes[2], fds, pid;

	if (*type != 'r' && *type != 'w' || type[1])
		return (NULL);

	if (pids == NULL) {
		if ((fds = getdtablesize()) <= 0)
			return (NULL);
		if ((pids = (int *)malloc((u_int)(fds * sizeof(int)))) == NULL)
			return (NULL);
		bzero((char *)pids, fds * sizeof(int));
	}
	if (pipe(pdes) < 0)
		return (NULL);
	switch (pid = vfork()) {
	case -1:			/* error */
		(void) close(pdes[0]);
		(void) close(pdes[1]);
		return (NULL);
		/* NOTREACHED */
	case 0:				/* child */
		if (*type == 'r') {
			if (pdes[1] != fileno(stdout)) {
				(void) dup2(pdes[1], fileno(stdout));
				(void) close(pdes[1]);
			}
			(void) close(pdes[0]);
		} else {
			if (pdes[0] != fileno(stdin)) {
				(void) dup2(pdes[0], fileno(stdin));
				(void) close(pdes[0]);
			}
			(void) close(pdes[1]);
		}
		execl("/bin/sh", "sh", "-c", program, NULL);
		_exit(127);
		/* NOTREACHED */
	}
	/* parent; assume fdopen can't fail...  */
	if (*type == 'r') {
		iop = fdopen(pdes[0], type);
		(void) close(pdes[1]);
	} else {
		iop = fdopen(pdes[1], type);
		(void) close(pdes[0]);
	}
	pids[fileno(iop)] = pid;
	return (iop);
}

int
pclose(iop)
	FILE *iop;
{
	register int fdes;
	sigset_t omask, nmask;
	union wait pstat;
	register int pid;

	/*
	 * pclose returns -1 if stream is not associated with a
	 * `popened' command, if already `pclosed', or waitpid
	 * returns an error.
	 */
	if (pids == NULL || pids[fdes = fileno(iop)] == 0)
		return (-1);
	(void) fclose(iop);
	sigemptyset(&nmask);
	sigaddset(&nmask, SIGINT);
	sigaddset(&nmask, SIGQUIT);
	sigaddset(&nmask, SIGHUP);
	(void) sigprocmask(SIG_BLOCK, &nmask, &omask);
	do {
		pid = waitpid(pids[fdes], (int *) &pstat, 0);
	} while (pid == -1 && errno == EINTR);
	(void) sigprocmask(SIG_SETMASK, &omask, NULL);
	pids[fdes] = 0;
	return (pid == -1 ? -1 : pstat.w_status);
}

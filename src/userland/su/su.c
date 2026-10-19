/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD su(1)
 *   vendor/2.11BSD/usr/bin/su.c (5.4.1 (2.11BSD) 1997/10/2), VERBATIM but for
 *   the one line noted below.  Copyright (c) 1980 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; the FGX header above is BSD-2-Clause (see LICENSE /
 *   docs/PROVENANCE.md).
 *
 * WHAT IT NEEDED WENT INTO libc: initgroups(3), which did not exist.  With
 * NGROUPS 1 (sys/param.h) it is setgid of the base gid, and it keeps its own
 * name because the CALLER's meaning is "install this user's groups" -- that is
 * what would change if FGX grew a list.  See libc_c/groups.c.
 *
 * THE GROUP-ZERO RULE IS UPSTREAM'S AND IS KEPT: only a member of group 0 in
 * /etc/group may su to root.  It is the reason su is worth having verbatim
 * rather than as a setuid shim -- FGX now has the credentials to enforce it
 * (UFS 2.6, apple/fgx#320) and /etc/group ships.
 *
 * The audit line goes to syslogd(8) through /dev/log, and upstream's
 * /etc/syslog.conf sends auth.notice to /usr/adm/messages and to /dev/console,
 * which is tty[0], the machine's own console -- not whichever console su was
 * invoked from.
 * BUGS: setpriority(2) is libc's and has no kernel behind it, so the nice bump
 * upstream gives a root su is inert.  On a session with no /etc/utmp record --
 * the primary console, where init's shell runs with no login(1) in front of it
 * -- getlogin(3) answers NULL and the audit line falls back to the caller's
 * passwd name, which is upstream's own fallback and names the same person.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if	!defined(lint) && defined(DOSCCS)
char copyright[] =
"@(#) Copyright (c) 1980 Regents of the University of California.\n\
 All rights reserved.\n";

static char sccsid[] = "@(#)su.c	5.4.1 (2.11BSD) 1997/10/2";
#endif

#include <stdio.h>
#include <pwd.h>
#include <grp.h>
#include <syslog.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>

char	userbuf[64]	= "USER=";
char	homebuf[128]	= "HOME=";
char	shellbuf[128]	= "SHELL=";
char	pathbuf[128]	= "PATH=:/usr/ucb:/bin:/usr/bin";
char	*cleanenv[] = { userbuf, homebuf, shellbuf, pathbuf, 0, 0 };
char	*user = "root";
char	*shell = "/bin/sh";
int	fulllogin;
int	fastlogin;

extern char	**environ;
struct	passwd *pwd;

main(argc,argv)
	int argc;
	char *argv[];
{
	char *password;
	char buf[1000];
	FILE *fp;
	register char *p;

	openlog("su", LOG_ODELAY, LOG_AUTH);

again:
	if (argc > 1 && strcmp(argv[1], "-f") == 0) {
		fastlogin++;
		argc--, argv++;
		goto again;
	}
	if (argc > 1 && strcmp(argv[1], "-") == 0) {
		fulllogin++;
		argc--, argv++;
		goto again;
	}
	if (argc > 1 && argv[1][0] != '-') {
		user = argv[1];
		argc--, argv++;
	}
	if ((pwd = getpwuid(getuid())) == NULL) {
		fprintf(stderr, "Who are you?\n");
		exit(1);
	}
	strcpy(buf, pwd->pw_name);
	if ((pwd = getpwnam(user)) == NULL) {
		fprintf(stderr, "Unknown login: %s\n", user);
		exit(1);
	}
	/*
	 * Only allow those in group zero to su to root.
	 */
	if (pwd->pw_uid == 0) {
		struct	group *gr;
		int i;

		if ((gr = getgrgid(0)) != NULL) {
			for (i = 0; gr->gr_mem[i] != NULL; i++)
				if (strcmp(buf, gr->gr_mem[i]) == 0)
					goto userok;
			fprintf(stderr, "You do not have permission to su %s\n",
				user);
			exit(1);
		}
	userok:
		setpriority(PRIO_PROCESS, 0, -2);
	}

#define Getlogin()  (((p = getlogin()) && *p) ? p : buf)
	if (pwd->pw_passwd[0] == '\0' || getuid() == 0)
		goto ok;
	password = getpass("Password:");
	/* crypt_salt(3) AND NOT THE WHOLE HASH, which is what upstream passes and
	 * is right for DES: a DES hash is its own salt, crypt() taking the first
	 * two characters and ignoring the rest.  FGX's hash is tagged
	 * "$f$xy$........", so its first two characters are "$f" -- crypt() folded
	 * those instead of "xy" and returned "$f$$f$........", which can never
	 * equal any stored hash.  su could not authenticate ANYBODY, for any
	 * password, and nothing noticed because no test had a caller that was
	 * non-root, in wheel, and su'ing to an account with a password
	 * (apple/fgx#414). */
	if (strcmp(pwd->pw_passwd,
		   crypt(password, crypt_salt(pwd->pw_passwd))) != 0) {
		fprintf(stderr, "Sorry\n");
		if (pwd->pw_uid == 0) {
			syslog(LOG_CRIT, "BAD SU %s on %s",
					Getlogin(), ttyname(2));
		}
		exit(2);
	}
ok:
	endpwent();
	if (pwd->pw_uid == 0) {
		syslog(LOG_NOTICE, "%s on %s", Getlogin(), ttyname(2));
		closelog();
	}
	if (setgid(pwd->pw_gid) < 0) {
		perror("su: setgid");
		exit(3);
	}
	if (initgroups(user, pwd->pw_gid)) {
		fprintf(stderr, "su: initgroups failed\n");
		exit(4);
	}
	if (setuid(pwd->pw_uid) < 0) {
		perror("su: setuid");
		exit(5);
	}
	if (pwd->pw_shell && *pwd->pw_shell)
		shell = pwd->pw_shell;
	if (fulllogin) {
		cleanenv[4] = getenv("TERM");
		environ = cleanenv;
	}
	if (strcmp(user, "root"))
		setenv("USER", pwd->pw_name, userbuf);
	setenv("SHELL", shell, shellbuf);
	setenv("HOME", pwd->pw_dir, homebuf);
	setpriority(PRIO_PROCESS, 0, 0);
	if (fastlogin) {
		*argv-- = "-f";
		*argv = "su";
	} else if (fulllogin) {
		if (chdir(pwd->pw_dir) < 0) {
			fprintf(stderr, "No directory\n");
			exit(6);
		}
		*argv = "-su";
	} else
		*argv = "su";
	execv(shell, argv);
	fprintf(stderr, "No shell\n");
	exit(7);
}

setenv(ename, eval, buf)
	char *ename, *eval, *buf;
{
	register char *cp, *dp;
	register char **ep = environ;

	/*
	 * this assumes an environment variable "ename" already exists
	 */
	while (dp = *ep++) {
		for (cp = ename; *cp == *dp && *cp; cp++, dp++)
			continue;
		if (*cp == 0 && (*dp == '=' || *dp == 0)) {
			strcat(buf, eval);
			*--ep = buf;
			return;
		}
	}
}

char *
getenv(ename)
	char *ename;
{
	register char *cp, *dp;
	register char **ep = environ;

	while (dp = *ep++) {
		for (cp = ename; *cp == *dp && *cp; cp++, dp++)
			continue;
		if (*cp == 0 && (*dp == '=' || *dp == 0))
			return (*--ep);
	}
	return ((char *)0);
}

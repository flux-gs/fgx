/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Origin: original -- FGX code.  It names 4.3BSD only to say whose RULE
 *   the kernel implements; no upstream program looks like this.
 */
/* credtest -- can an unprivileged process give itself a credential it was not
 * given?  Run it as a NON-ROOT user; as root every call is permitted and it
 * says nothing.
 *
 * setuid(2)'s rule (4.3BSD+, and _Cred_Set's header states it): a non-root
 * caller may set an id only if the new id equals its REAL or its SAVED-SET id,
 * and then only the effective id moves.  Anything else is EPERM.  So from an
 * ordinary account setgid(0) and setuid(0) must both fail, and the ids must be
 * unchanged afterwards -- the second half being the one that matters, since a
 * call that reports failure and acts anyway is worse than one that reports
 * success.
 */
#include <stdio.h>
#include <errno.h>
#include <unistd.h>

main()
{
	int r;

	printf("CRED start uid=%d euid=%d gid=%d egid=%d\n",
	       getuid(), geteuid(), getgid(), getegid());

	errno = 0;
	r = setgid(0);
	printf("CRED setgid(0) r=%d errno=%d -> gid=%d egid=%d\n",
	       r, errno, getgid(), getegid());

	errno = 0;
	r = setuid(0);
	printf("CRED setuid(0) r=%d errno=%d -> uid=%d euid=%d\n",
	       r, errno, getuid(), geteuid());

	printf("CRED %s\n", (geteuid() == 0 || getegid() == 0)
	                    ? "ESCALATED" : "REFUSED");
	return (0);
}

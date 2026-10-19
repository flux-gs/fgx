/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD mount(8)
 *   vendor/2.11BSD/usr/sbin/mount/mount_ufs.c, VERBATIM but for the one
 *   FGX DELTA at the mount(2) call.
 *   Copyright (c) 1980, 1989, 1993, 1994 The Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; the FGX header above is BSD-2-Clause (see LICENSE /
 *   docs/PROVENANCE.md).
 */
/*-
 * Copyright (c) 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#if	!defined(lint) && defined(DOSCCS)
static char copyright[] =
"@(#) Copyright (c) 1993, 1994\n\
	The Regents of the University of California.  All rights reserved.\n";

static char sccsid[] = "@(#)mount_ufs.c	8.2.2 (2.11BSD) 1996/4/18";
#endif /* not lint */

#include <sys/param.h>
#include <sys/mount.h>

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "mntopts.h"

void	ufs_usage();

static struct mntopt mopts[] = {
	MOPT_STDOPTS,
	MOPT_ASYNC,
	MOPT_SYNC,
	MOPT_UPDATE,
	{ NULL }
};

int
mount_ufs(argc, argv)
	int argc;
	register char *argv[];
{
	extern int optreset;
	int ch, mntflags;

	mntflags = 0;
	optind = optreset = 1;		/* Reset for parse of new argv. */
	while ((ch = getopt(argc, argv, "o:")) != EOF)
		switch (ch) {
		case 'o':
			getmntopts(optarg, mopts, &mntflags);
			break;
		case '?':
		default:
			ufs_usage();
		}
	argc -= optind;
	argv += optind;

	if (argc != 2)
		ufs_usage();

	/* FGX DELTA.  Upstream is `mount(argv[0], argv[1], mntflags)', 2.11BSD's
	 * smount, which has no filesystem type.  The kernel's mount(2) is
	 * 4.3BSD-Reno's `mount(type, dir, flags, data)' so that a type can be
	 * named at all, and for MOUNT_UFS `data' is the special file. */
	if (mount(MOUNT_UFS, argv[1], mntflags, argv[0]) < 0) {
		(void)fprintf(stderr, "%s on %s: ", argv[0], argv[1]);
		switch (errno) {
		case EMFILE:
			(void)fprintf(stderr, "mount table full.\n");
			break;
		case EINVAL:
			if (mntflags & MNT_UPDATE)
				(void)fprintf(stderr,
		    "Specified device does not match mounted device.\n");
			else 
				(void)fprintf(stderr,
				    "Incorrect super block.\n");
			break;
		default:
			(void)fprintf(stderr, "%s\n", strerror(errno));
			break;
		}
		fflush(stderr);
		return (1);
	}
	return (0);
}

void
ufs_usage()
{
	(void)fprintf(stderr, "usage: mount_ufs [-o options] special node\n");
	exit(1);
}

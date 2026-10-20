/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD mount(8)
 *   vendor/2.11BSD/usr/sbin/mount/mount_ufs.c, as a standalone mount_<type>
 *   for the filesystem type it has no back end for.  FGX DELTAS: a main()
 *   where upstream's is a function mount.c calls in-process, because
 *   mount.c:298-305 execs /sbin/mount_<type> for every type but ufs; the
 *   type is MOUNT_PRODOS; EINVAL reads "not a ProDOS volume", which is
 *   what prodos_mount answers it for; a writable mount needs `-o write',
 *   without which the mount is made read-only and SAID to be; and a
 *   writable mount the kernel refuses with EROFS is retried read-only and
 *   said to be, where
 *   netbsd-0-9's mount_isofs forces MNT_RDONLY silently
 *   (sbin/mount_isofs/mount_isofs.c: opts = MNT_RDONLY) and SunOS 4.1.3's
 *   mount_hsfs refuses outright ("must be mounted readonly").  The ProDOS
 *   modules are not loaded at boot: a mount the kernel answers ENODEV (no
 *   such type configured, vfs_syscalls.c) loads prodos -- and prodosw for
 *   `-o write' -- with modload(8) and is retried, and a writable mount
 *   answered EROFS loads prodosw before its retry.  No counterpart in
 *   2.11BSD, 4.3BSD-Reno or netbsd-0-9, none of which loads a filesystem
 *   at mount time.
 *   Copyright (c) 1993, 1994 The Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; the FGX
 *   header above is BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
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

#include <sys/param.h>
#include <sys/mount.h>

#include <sys/wait.h>

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "../mount/mntopts.h"

void	prodos_usage();
static int pd_modload();

/* `-o write' IS mount_prodos's OWN OPTION, carried in a bit of mntflags that
 * no MNT_ flag uses (MNT_VISFLAGMASK's 0x0800) and cleared before mount(2)
 * sees it. */
#define PDOPT_WRITE	0x0800

static struct mntopt mopts[] = {
	MOPT_STDOPTS,
	MOPT_UPDATE,
	{ "write", 0, PDOPT_WRITE },
	{ NULL }
};

int
main(argc, argv)
	int argc;
	register char *argv[];
{
	int ch, mntflags, rv, forced;

	mntflags = 0;
	while ((ch = getopt(argc, argv, "o:")) != EOF)
		switch (ch) {
		case 'o':
			getmntopts(optarg, mopts, &mntflags);
			break;
		case '?':
		default:
			prodos_usage();
		}
	argc -= optind;
	argv += optind;

	if (argc != 2)
		prodos_usage();

	/* WRITING A ProDOS VOLUME IS ASKED FOR BY NAME.  The write path is new
	 * and the disk is somebody's, so a mount without `-o write' is made
	 * read-only -- and a caller who did not ask for read-only is told. */
	forced = (mntflags & (PDOPT_WRITE | MNT_RDONLY)) == 0;
	if (forced)
		mntflags |= MNT_RDONLY;
	mntflags &= ~PDOPT_WRITE;

	/* A MOUNT THAT CANNOT BE WRITABLE IS STILL A MOUNT.  A writable mount
	 * the kernel refuses with EROFS is retried read-only, and the caller is
	 * told. */
	rv = mount(MOUNT_PRODOS, argv[1], mntflags, argv[0]);
	if (rv < 0 && errno == ENODEV && pd_modload("prodos", 0) == 0) {
		if ((mntflags & MNT_RDONLY) == 0)
			(void)pd_modload("prodosw", 0);
		rv = mount(MOUNT_PRODOS, argv[1], mntflags, argv[0]);
	}
	/* EROFS ON A WRITABLE MOUNT MAY ONLY MEAN THE WRITE HALF IS NOT IN.
	 * modload(8) refuses a module already loaded, so it is asked quietly
	 * and a refusal leaves the retry to answer for the volume itself. */
	if (rv < 0 && errno == EROFS && (mntflags & MNT_RDONLY) == 0 &&
	    pd_modload("prodosw", 1) == 0)
		rv = mount(MOUNT_PRODOS, argv[1], mntflags, argv[0]);
	if (rv < 0 && errno == EROFS && (mntflags & MNT_RDONLY) == 0) {
		rv = mount(MOUNT_PRODOS, argv[1], mntflags | MNT_RDONLY, argv[0]);
		if (rv == 0)
			(void)fprintf(stderr, "%s on %s: %s, mounted read-only.\n",
			    argv[0], argv[1], strerror(EROFS));
	}
	if (rv == 0 && forced)
		(void)fprintf(stderr,
		    "%s on %s: writing needs -o write, mounted read-only.\n",
		    argv[0], argv[1]);
	if (rv < 0) {
		(void)fprintf(stderr, "%s on %s: ", argv[0], argv[1]);
		switch (errno) {
		case EMFILE:
			(void)fprintf(stderr, "mount table full.\n");
			break;
		case EINVAL:
			(void)fprintf(stderr, "not a ProDOS volume.\n");
			break;
		default:
			(void)fprintf(stderr, "%s\n", strerror(errno));
			break;
		}
		fflush(stderr);
		exit(1);
	}
	exit(0);
}

/* Load module `name' with /sbin/modload; 0 when it came up.  `quiet' sends
 * modload's own messages to /dev/null. */
static int
pd_modload(name, quiet)
	char *name;
	int quiet;
{
	char *av[3];
	int pid, st, fd;

	av[0] = "modload";
	av[1] = name;
	av[2] = (char *)0;
	pid = fork();
	if (pid == 0) {
		if (quiet && (fd = open("/dev/null", O_WRONLY)) >= 0) {
			(void)dup2(fd, 1);
			(void)dup2(fd, 2);
		}
		execv("/sbin/modload", av);
		_exit(127);
	}
	if (pid < 0 || waitpid(pid, &st, 0) != pid)
		return (-1);
	return (st == 0 ? 0 : -1);
}

void
prodos_usage()
{
	(void)fprintf(stderr, "usage: mount_prodos [-o options] special node\n");
	exit(1);
}

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD mount(8)
 *   vendor/2.11BSD/usr/sbin/mount/mount_ufs.c, by way of mount_prodos.c, as
 *   the standalone mount_<type> mount.c execs for `-t isofs', with
 *   netbsd-0-9's sbin/mount_isofs/mount_isofs.c for what it does: always
 *   MNT_RDONLY, as upstream's `opts = MNT_RDONLY'.  FGX DELTAS: options are
 *   mount(8)'s `-o', parsed by its getmntopts, where netbsd-0-9 takes `-F'
 *   and `-norrip' by hand; the special is passed as mount(2)'s data, FGX's
 *   convention for every type; EINVAL reads "not an ISO 9660 volume"; and
 *   isofs.mod is not loaded at boot, so a mount the kernel answers ENODEV
 *   loads it with modload(8) and is retried -- mount_prodos(8)'s answer to
 *   the same question.
 *   Copyright (c) 1993, 1994 The Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; the FGX
 *   header above is BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
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

void	iso_usage();
static int iso_modload();

static struct mntopt mopts[] = {
	MOPT_STDOPTS,
	{ NULL }
};

int
main(argc, argv)
	int argc;
	register char *argv[];
{
	int ch, mntflags, rv;

	mntflags = 0;
	while ((ch = getopt(argc, argv, "o:")) != EOF)
		switch (ch) {
		case 'o':
			getmntopts(optarg, mopts, &mntflags);
			break;
		case '?':
		default:
			iso_usage();
		}
	argc -= optind;
	argv += optind;

	if (argc != 2)
		iso_usage();

	mntflags |= MNT_RDONLY;
	rv = mount(MOUNT_ISOFS, argv[1], mntflags, argv[0]);
	if (rv < 0 && errno == ENODEV && iso_modload("isofs") == 0)
		rv = mount(MOUNT_ISOFS, argv[1], mntflags, argv[0]);
	if (rv < 0) {
		(void)fprintf(stderr, "%s on %s: ", argv[0], argv[1]);
		switch (errno) {
		case EMFILE:
			(void)fprintf(stderr, "mount table full.\n");
			break;
		case EINVAL:
			(void)fprintf(stderr, "not an ISO 9660 volume.\n");
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

/* Load module `name' with /sbin/modload; 0 when it came up.  mount_prodos's
 * pd_modload. */
static int
iso_modload(name)
	char *name;
{
	char *av[3];
	int pid, st;

	av[0] = "modload";
	av[1] = name;
	av[2] = (char *)0;
	pid = fork();
	if (pid == 0) {
		execv("/sbin/modload", av);
		_exit(127);
	}
	if (pid < 0 || waitpid(pid, &st, 0) != pid)
		return (-1);
	return (st == 0 ? 0 : -1);
}

void
iso_usage()
{
	(void)fprintf(stderr, "usage: mount_isofs [-o options] special node\n");
	exit(1);
}

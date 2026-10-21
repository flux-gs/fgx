/* SPDX-License-Identifier: LicenseRef-SunOS
 *
 * Copyright (c) 1989 Sun Microsystems, Inc. All rights reserved.
 *
 * eject - program to eject removeable media
 *
 * FGX-Provenance: vendor/SunOS-4.1.3/usr.bin/eject.c.  Changes: the devices
 * are FGX's CD-ROMs, /dev/cd0 to /dev/cd3, and the floppy entries are gone;
 * the ioctl is netbsd-0-9's CDIOCEJECT, where upstream asks FDKEJECT of every
 * device; and FGX has no raw CD-ROM device, so the BLOCK device is the one
 * opened.  That moves try_unmount AHEAD of the open, because a block device
 * with a filesystem mounted on it cannot be opened (spec_open answers EBUSY,
 * as Reno's does) -- and it means -f cannot eject a disc that will not
 * unmount.  try_unmount reads the kernel's mount table with getmntinfo(3),
 * there being no mtab, and unmounts with 2.11BSD's umount(2), which takes
 * the special file; upstream's follow-up umount(8) run, which only tidies
 * the mtab, goes with it.  -q reads the first block, since an empty drive
 * opens here where upstream's could not.  `c' is an int, so getopt's -1 is
 * seen where char is unsigned.
 *
 * returns exit codes:	(KEEP THESE - especially important for query)
 *	0 = -n, -d or eject operation was ok, -q = media in drive
 *	1 = -q only = media not in drive
 *	2 = various parameter errors, etc.
 *	3 = eject ioctl failed
 */
#include <sys/types.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/cdio.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

#define	STILL_MOUNTED	0
#define	UNMOUNTED	1

char *myname;
char *default_dev = { "/dev/cd0" };

struct niknames {
	char	*nn;
	char	*rn;
} niknames[] = {
/* nicknames for cdrom */
	{ "cd", "/dev/cd0" },
	{ "cdrom", "/dev/cd0" },
	{ "cd0", "/dev/cd0" },
	{ "cd1", "/dev/cd1" },
	{ "cd2", "/dev/cd2" },
	{ "cd3", "/dev/cd3" },
	{ 0, 0 }
};

char blk[512];

main(argc, argv)
int	argc;
char	*argv[];
{
	int	fd;
	int	err;
	int	force = 0;
	int	query = 0;
	int	out = -1;
	int	c;
	char	*fname, *opened;
	struct niknames *np;
	extern char *optarg;
	extern int optind, opterr;
	struct stat st;

	myname = argv[0];

	while ((c = getopt(argc, argv, "dfnq")) != -1) {
		switch (c) {
		case 'd':	/* show default */
			(void)printf("%s: default device is \"%s\"\n", myname,
			    default_dev);
			out = 0;
			break;

		case 'f':	/* force eject, even if busy */
			force++;
			break;

		case 'n':	/* print nicknames */
			(void)printf("%s: nicknames are:\n", myname);
			for (np = niknames; np->nn; np++) {
				(void)printf("\t%s -> %s\n", np->nn, np->rn);
			}
			out = 0;
			break;

		case 'q':	/* query - see if device is there? */
			query++;
			break;

		case '?':
			(void)printf("usage: %s -dfnq [ name | nickname ]\n",
			    myname);
			(void)printf("\toptions: -d  show default device\n");
			(void)printf(
			    "\t\t -f  force eject even if device is mounted\n");
			(void)printf("\t\t -n  show nicknames\n");
			(void)printf("\t\t -q  query for media present\n");
			out = 2;
		}
	}
	if (out != -1)
		exit(out);	/* 0 = ok (for -d, -n); 2 = error - bad flag */
		/* NOTREACHED */

	if (optind == argc)
		fname = default_dev;
	else
		fname = argv[optind];

	/* go to /dev so short path names work smoothly */
	(void)chdir("/dev");

	opened = fname;
	if ((stat(fname, &st) == -1) || ((st.st_mode & S_IFMT) != S_IFBLK)) {
		/*
		 * we can't find the named -OR- it isn't a block device
		 * (upon which ioctls are possible), check for nicknames
		 * like "cd", "cdrom", ... before giving up.
		 */
		for (np = niknames; np->nn; np++) {
			if (strcmp(fname, np->nn) == 0)
				break;
		}
		if (np->nn == 0) {
			(void)fprintf(stderr,
		    "%s: Open fail on %s, and no nickname found: ",
			    myname, fname);
			perror("");
			exit(2);
		}
		opened = np->rn;
	}

	/*
	 * Check to see if this device contains a mounted filesystem, and
	 * try to unmount it: the open below cannot succeed while it does.
	 */
	if (!query && try_unmount(opened) == STILL_MOUNTED) {
		if (force) {
			(void)fprintf(stderr,
			    "Warning: device \"%s\" has mounted partitions.\n",
			    fname);
		} else {
			(void)fprintf(stderr, "%s: Eject of \"%s\" failed: ",
			    myname, fname);
			perror("");
			exit(1);
		}
	}

	if ((fd = open(opened, O_RDONLY|O_NDELAY)) == -1) {
		(void)fprintf(stderr, "%s: Open fail on %s: ", myname, opened);
		perror("");
		exit(2);
	}

	/* XXX query overrides eject */
	if (query) {
		/*
		 * The drive opens with or without a disc in it, so the
		 * question is whether its first block reads.
		 */
		if (read(fd, blk, sizeof blk) > 0) {
			fprintf(stdout, "CD-ROM is in drive\n");
			exit(0);
		}
		fprintf(stdout, "CD-ROM NOT in drive\n");
		exit(1);
	}

	err = ioctl(fd, CDIOCEJECT, (char *)0);

	if (err == -1) {
		(void)fprintf(stderr, "%s: Eject of \"%s\" failed: ",
		    myname, fname);
		perror("");
		exit(3);
	}
	exit(0);
}

/*
 * Attempt to discern whether the device to be ejected has any mounted
 * partitions. Be lenient by design: if any part of the test fails,
 * allow the eject. Hopefully even if many things go wrong, you won't
 * have to resort to the paper clip.
 */
int
try_unmount(bdev)
	char *bdev;
{
	struct stat st;
	dev_t bdevno;
	struct statfs *mntbuf;
	int i, n;

	if (stat(bdev, &st) != 0) {
		(void)fprintf(stderr, "%s: Couldn't stat \"%s\": ",
		    myname, bdev);
		perror("");
		return (UNMOUNTED);
	}
	if ((st.st_mode & S_IFMT) != S_IFBLK) {
		/*
		 * What is this thing? Ferget it!
		 */
		return (UNMOUNTED);
	}
	bdevno = st.st_rdev;

	/*
	 * Now go through the mount table.  Compare the device mounted with
	 * our bdevno.
	 */
	if ((n = getmntinfo(&mntbuf, MNT_NOWAIT)) == 0) {
		(void)fprintf(stderr, "%s: Couldn't read the mount table\n",
		    myname);
		return (UNMOUNTED);
	}
	for (i = 0; i < n; i++) {
		if (stat(mntbuf[i].f_mntfromname, &st) != 0) {
			continue;
		}
		if (((st.st_mode & S_IFMT) == S_IFBLK) &&
		    (st.st_rdev == bdevno)) {
			/*
			 * The unmount syscall returns reliable status.
			 */
			if (umount(mntbuf[i].f_mntfromname) < 0) {
				return (STILL_MOUNTED);
			}
		}
	}
	return (UNMOUNTED);
}

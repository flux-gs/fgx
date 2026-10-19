/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sbin/fsck/main.c
 *   Ported from usr/sbin/fsck/main.c, 2.11BSD.  Original work:
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
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

static char sccsid[] = "@(#)main.c	5.4.1 (2.11BSD) 1996/2/3";
#endif not lint

#include "ufsdisk.h"
#include <sys/stat.h>
#include <sys/wait.h>
#include <fstab.h>
#include <strings.h>
#include <sys/mount.h>
#include "fsck.h"
#include <stdio.h>

char	*rawname(), *unrawname(), *blockcheck();
int	catch(), catchquit(), voidquit();
int	returntosingle;
/* UPSTREAM DECLARES `int (*signal())();' HERE AND FGX TAKES IT FROM <signal.h>
 * INSTEAD.  Two reasons, and the second is the binding one:
 *
 *   fcc cannot parse a function returning a pointer to a function -- the
 *   `( declarator )' grouping production is not implemented (the diagnostic
 *   points at declarator-refactor Increment 4, though the charter records that
 *   increment as done and describing the return-type work instead).
 *
 *   Even parsed, the declaration would CONTRADICT the system header.  FGX
 *   declares `char *signal(int sig, char *handler)' and signal.h states the
 *   true BSD shape it is standing in for, `void (*signal(int sig, void
 *   (*func)()))();' -- a deliberate, documented divergence that predates this
 *   port, made because that type is inexpressible here.
 *
 * So the redeclaration goes and <signal.h> supplies it; utilities.c already
 * calls signal(2) that way.  Recorded in PROVENANCE as an FGX delta. */
#include <signal.h>

main(argc, argv)
	int	argc;
	char	*argv[];
{
	struct fstab *fsp;
	int pid, passno, anygtr, sumstatus;
	char *name, inbuf[128], outbuf[128];

	setbuffer(stdin, inbuf, sizeof (inbuf));
	setbuffer(stdout, outbuf, sizeof (outbuf));
	setlinebuf(stdout);
	sync();

	while (--argc > 0 && **++argv == '-') {
		switch (*++*argv) {

		case 's':
			sflag++;
			stype(++*argv);
			argc--;
			break;

		case 't':
		case 'T':
			if (**++argv == '-' || --argc <= 0)
				errexit("Bad -t option");
			strcpy(scrfile, *argv);
			break;

		case 'p':
			preen++;
			break;

		case 'f':	/* force check */
			fflag++;
			break;

		case 'd':
			debug++;
			break;

		case 'n':	/* default no answer flag */
		case 'N':
			nflag++;
			yflag = 0;
			break;

		case 'y':	/* default yes answer flag */
		case 'Y':
			yflag++;
			nflag = 0;
			break;

		default:
			errexit("%c option?\n", **argv);
		}
	}

	/*
	 * fsck has a problem under a 4BSD C library in that if its done
	 * its sbrk's before it accesses FSTAB, there's no space left
	 * for stdio.  There may be other problems like this.  Enjoy.
	 */
	if (!getfsent())
		errexit("Can't open checklist file: %s\n",FSTAB);
	setpassent(1);

	/* HOW BIG AN ARENA TO ASK FOR: everything between the current break
	 * and the segment ceiling, which is upstream's arithmetic unchanged.
	 * What it buys is not roundness, it is that the arena TRACKS THIS
	 * PROGRAM'S OWN SIZE.  A constant has to be retuned whenever fsck's bss
	 * moves and is silent when it is not: the volume that no longer fits
	 * just starts needing a scratch file, which for the root is a refusal.
	 *
	 * The whole ask goes in ONE sbrk, as it does upstream: the increment is
	 * an unsigned addend and the kernel validates the sum, so some 34 KB on
	 * this build's root is an ordinary grow.  MAXDATA is still only a
	 * ceiling, and the back-off loop is what asks the kernel whether the
	 * break can really reach it -- on a PDP-11 whose data segment is already
	 * large it cannot, and the loop steps down MEMUNIT at a time until it
	 * can.  Against maps of 24,004 bytes for the 32000-block root, the
	 * arena has room to spare. */
	memsize = (unsigned)(unsigned long)sbrk(0);
	memsize = MAXDATA - memsize - sizeof(int);
	while (memsize >= 2 * sizeof(BUFAREA) &&
		(membase = (char *)sbrk(memsize)) == (char *)-1)
		memsize -= MEMUNIT;
	if (memsize < 2 * sizeof(BUFAREA))
		errexit("Can't get memory\n");

	if (signal(SIGINT, SIG_IGN) != SIG_IGN)
		(void)signal(SIGINT, catch);
	if (preen)
		(void)signal(SIGQUIT, catchquit);
	if (argc) {
		while (argc-- > 0) {
			hotroot = 0;
			checkfilesys(*argv++);
		}
		exit(0);
	}
	sumstatus = 0;
	passno = 1;
	do {
		anygtr = 0;
		if (setfsent() == 0)
			errexit("Can't open %s\n", FSTAB);
		while ((fsp = getfsent()) != 0) {
			if (strcmp(fsp->fs_vfstype, "ufs") ||
			    (strcmp(fsp->fs_type, FSTAB_RW) &&
			    strcmp(fsp->fs_type, FSTAB_RO) &&
			    strcmp(fsp->fs_type, FSTAB_RQ)) ||
			    fsp->fs_passno == 0)
				continue;
			if (preen == 0 ||
			    passno == 1 && fsp->fs_passno == passno) {
				name = blockcheck(fsp->fs_spec);
				if (name != NULL)
					checkfilesys(name);
				else if (preen)
					exit(8);
			} else if (fsp->fs_passno > passno) {
				anygtr = 1;
			} else if (fsp->fs_passno == passno) {
				pid = fork();
				if (pid < 0) {
					perror("fork");
					exit(8);
				}
				if (pid == 0) {
					(void)signal(SIGQUIT, voidquit);
					name = blockcheck(fsp->fs_spec);
					if (name == NULL)
						exit(8);
					checkfilesys(name);
					exit(0);
				}
			}
		}
		if (preen) {
			union wait status;
			while (wait(&status) != -1)
				sumstatus |= status.w_retcode;
		}
		passno++;
	} while (anygtr);

	if (sumstatus)
		exit(8);
	(void)endfsent();
	if (returntosingle)
		exit(2);
	exit(0);
}

checkfilesys(filesys)
	char *filesys;
{
	daddr_t n_ffree, n_bfree;
	register ino_t *zp;
	int i;

	devname = filesys;
	if ((i = setup(filesys)) == 0) {
		if (preen)
			pfatal("CAN'T CHECK FILE SYSTEM.");
		return;
	}
	/* A CLEAN FILE SYSTEM IS NOT CHECKED, 2.11BSD update #456.  setup()
	 * answers -1 for one, and this is upstream's line for it -- the
	 * `%sile' is their own trick for printing `file' under -p and
	 * `** File' otherwise. */
	if (i < 0) {
		pwarn("%sile system is clean; not checking\n",
		      preen ? "f" : "** F");
		return;
	}
	/*
	 * 1: scan inodes tallying blocks used
	 */
	if (preen == 0) {
		printf("** Last Mounted on %.*s\n", MAXMNTLEN, &sblk.b_un.b_buf[SB_FSMNT]);
		if (hotroot)
			printf("** Root file system\n");
		printf("** Phase 1 - Check Blocks and Sizes\n");
	}
	pass1();

	/*
	 * 1b: locate first references to duplicates, if any
	 */
	if (enddup != duplist) {
		if (preen)
			pfatal("INTERNAL ERROR: dups with -p");
		printf("** Phase 1b - Rescan For More DUPS\n");
		pass1b();
	}

	/*
	 * 2: traverse directories from root to mark all connected directories
	 */
	if (preen == 0)
		printf("** Phase 2 - Check Pathnames\n");
	pass2();

	/*
	 * 3: scan inodes looking for disconnected directories
	 */
	if (preen == 0)
		printf("** Phase 3 - Check Connectivity\n");
	pass3();

	/*
	 * 4: scan inodes looking for disconnected files; check reference counts
	 */
	if (preen == 0)
		printf("** Phase 4 - Check Reference Counts\n");
	pass4();

	flush(&dfile, &fileblk);

	/*
	 * 5: check and repair resource counts in cylinder groups
	 */
	if (preen == 0)
		printf("** Phase 5 - Check Free List\n");
	pass5();

	/*
	 * print out summary statistics
	 */
	pwarn("%ld files, %ld used, %ld free\n",
	    n_files, n_blks, sblock.sb_tfree);
	if (debug && (n_files -= imax - ROOTINO - sblock.sb_tinode))
		printf("%ld files missing, imax: %u tinode: %u\n", n_files,
			imax,sblock.sb_tinode);
	if (debug) {
		if (enddup != duplist) {
			printf("The following duplicate blocks remain:");
			for (; enddup > duplist; enddup--)
				printf(" %ld,", *enddup);
			printf("\n");
		}
		for (zp = zlnlist; zp < zlnp; zp++)
			if (*zp) break;
		if (zp < zlnp) {
			printf("The following zero link count inodes remain:");
			for (zp = zlnlist; zp < zlnp; zp++)
				if (*zp) printf(" %ld,", *zp);
			printf("\n");
		}
	}
	bzero(zlnlist, sizeof zlnlist);
	bzero(duplist, sizeof duplist);
	if (dfile.mod) {
		(void)time(&sblock.sb_time);
		sbdirty();
	}

	/* AND NOW IT IS CLEAN, WHICH IS THE OTHER HALF OF #456: a check that
	 * finished is the only thing entitled to say so.
	 *
	 * Note: The root filesystem is special, since it
	 *       is already mounted (hotroot). For this one
	 *       we instead look at WASCLEAN, since it reflect
	 *       the clean status at mount time.
	 *
	 * NOT AFTER A `no', which is upstream's `noflag' and is the condition
	 * that keeps this honest: -n, or any question answered no, means an
	 * inconsistency was found and left, and a volume with a known fault
	 * must not be stamped clean for the next boot to skip. */
	if ((sblock.sb_flags & MNT_CLEAN) == 0) {
		if (!(hotroot && (sblock.sb_flags & MNT_WASCLEAN))) {
			if (!noflag) {
				pwarn("Marking file system clean\n");
				sblock.sb_flags |= MNT_CLEAN | MNT_WASCLEAN;
				sbdirty();
			}
		}
	}

	ckfini();
	if (!dfile.mod)
		return;
	if (!preen) {
		printf("\n***** FILE SYSTEM WAS MODIFIED *****\n");
		if (hotroot)
			printf("\n***** REBOOT UNIX *****\n");
	}
	if (hotroot) {
		sync();
		exit(4);
	}
}

char *
/* THE HOT ROOT IS CHECKED THROUGH ITS RAW DEVICE, WHICH IS 4.3BSD-RENO'S
 * ARRANGEMENT AND NOT 2.11BSD'S.  Upstream marks the root and then converts the
 * name BACK to the block device:
 *
 *	if (stchar.st_mode & S_IFCHR) {
 *		if (stslash.st_dev == stblock.st_rdev) {
 *			hotroot++;
 *			raw = unrawname(name);
 *		}
 *		return (raw);
 *
 * so 2.11BSD's fsck opens the block device of a mounted filesystem, and its
 * kernel has to permit that -- which it does, gated on securelevel, with its
 * own comment saying the arrangement is a concession: "2.11BSD must relax this
 * restriction to allow 'fsck' to open the root filesystem ... On the otherhand
 * fsck should 1) use the raw device, 2) not do sync calls"
 * (usr/sys/sys/sys_inode.c, the IFBLK arm).
 *
 * Reno does what that comment asks: it sets hotroot and returns the raw name
 * anyway (sbin/fsck/preen.c:263), so nothing ever hands a mounted block device
 * to open(2) and spec_open can refuse one unconditionally, which Reno's does
 * (kern/spec_vnops.c:139) with no securelevel anywhere.
 *
 * FGX's kernel is Reno's, so this follows Reno.  The two halves do not compose
 * otherwise: 2.11BSD's spelling hands a block name to a kernel that refuses
 * block names, and the boot fsck would fail on the root it exists to check.
 * hotroot still means what it means -- it is set here, and both the clean-flag
 * skip and the sync at exit read it.
 */
blockcheck(name)
	char *name;
{
	struct stat stslash, stblock, stchar;
	char *raw;
	int looped = 0;

	hotroot = 0;
	if (stat("/", &stslash) < 0){
		printf("Can't stat root\n");
		return (0);
	}
retry:
	if (stat(name, &stblock) < 0){
		printf("Can't stat %s\n", name);
		return (0);
	}
	if (stblock.st_mode & S_IFBLK) {
		if (stslash.st_dev == stblock.st_rdev)
			hotroot++;
		raw = rawname(name);
		if (stat(raw, &stchar) < 0){
			printf("Can't stat %s\n", raw);
			return (0);
		}
		if (stchar.st_mode & S_IFCHR) {
			return (raw);
		} else {
			printf("%s is not a character device\n", raw);
			return (0);
		}
	} else if (stblock.st_mode & S_IFCHR) {
		if (looped) {
			printf("Can't make sense out of name %s\n", name);
			return (0);
		}
		name = unrawname(name);
		looped++;
		goto retry;
	}
	printf("Can't make sense out of name %s\n", name);
	return (0);
}

char *
unrawname(cp)
	char *cp;
{
	char *dp = rindex(cp, '/');
	struct stat stb;

	if (dp == 0)
		return (cp);
	if (stat(cp, &stb) < 0)
		return (cp);
	if ((stb.st_mode&S_IFMT) != S_IFCHR)
		return (cp);
	if (*(dp+1) != 'r')
		return (cp);
	(void)strcpy(dp+1, dp+2);
	return (cp);
}

char *
rawname(cp)
	char *cp;
{
	static char rawbuf[32];
	char *dp = rindex(cp, '/');

	if (dp == 0)
		return (0);
	*dp = 0;
	(void)strcpy(rawbuf, cp);
	*dp = '/';
	(void)strcat(rawbuf, "/r");
	(void)strcat(rawbuf, dp+1);
	return (rawbuf);
}

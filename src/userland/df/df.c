/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD df(1)
 *   vendor/2.11BSD/usr/bin/df.c (8.7.2, 1996/1/18) brought to 8.8 (2020/3/19)
 *   by vendor/2.11BSD/patches/466, VERBATIM but for the ufs_df() raw-device
 *   half -- see the note below.
 *
 *   -h IS UPSTREAM'S, AND A FIRST PASS HERE CLAIMED IT WAS NOT.  The 1996
 *   base has only -i, so "no BSD df FGX ports from has -h" looked true against
 *   2.11BSD, 4.3BSD-Reno, netbsd-0-9, SunOS 4.1.3 and GNO -- and an FGX
 *   extension with a K/M/G humanize() was written on that reading.  It was
 *   wrong: 2.11BSD patch 466 (2020) adds -h, and its own Repeat-By is the
 *   exact symptom this tree had, `df: illegal option -- h'.  Upstream's -h
 *   means MEGABYTES with one decimal, not auto-scaling units.  480 patches
 *   were sitting unread in the tree while the claim was made.
 *   Copyright (c) 1980, 1990, 1993, 1994 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; the FGX header above is BSD-2-Clause (see LICENSE /
 *   docs/PROVENANCE.md).
 *
 * WHY 2.11BSD AND NOT 4.3BSD-Reno, the VFS having come from Reno.  Reno's df
 * (bin/df/df.c) is line-for-line the same program in its statfs half, and its
 * ufs_df() reads an FFS superblock: fs_cstotal.cs_nbfree, fs_frag, fs_minfree,
 * fs_ncg, fs_ipg, fs_dsize.  FGX's filesystem HAS NONE OF THOSE -- it is
 * 2.11BSD's, and src/kernel/vfs/ufs_vfsops.c says so where it explains that
 * ufs_statfs is 2.11BSD's statfs1 "because Reno computes free space from a
 * cylinder-group summary a 2.11BSD volume does not have".  Porting Reno's df
 * would mean writing an FFS reader for a filesystem that is not FFS.
 *
 * 2.11BSD's is also the NEWER program: 8.7.2 (1996) is the 4.4BSD df
 * backported, with fsbtoblk()'s overflow avoidance and a 1K-block default;
 * Reno's is the 1990 one with neither.  The VFS-shaped half of this work is
 * Reno's and it is in the KERNEL -- statfs(2) and getfsstat(2), which dispatch
 * through the vfsops vector.  Nothing in df(1) touches a vnode.
 *
 *----------------------------------------------------------------------------
 * THE ONE DIVERGENCE: ufs_df() AND bread() ARE NOT BUILT.  They are df's
 * pre-syscall path -- open the raw device, read the superblock, fill a
 * `struct statfs' by hand -- and they are reached only for a `df /dev/rxxx'
 * argument that stat(2) reports as a character or block special.
 *
 * The obstacle is BYTE ORDER, not scope.  Upstream overlays `struct fs' on the
 * bytes bread() returns and reads sblock.fs_isize directly.  A 2.11BSD volume
 * is written in PDP-11 order, so on the 65816 that overlay reads garbage --
 * which is why the KERNEL has ufs_sbdecode() (src/kernel/vfs/ufs_sb.c) and why
 * fsck(8) carries its own decoder in src/userland/fsck/ufsdisk.h.  Making
 * ufs_df() work means giving df a third copy of that decoder or sharing
 * fsck's, and that is a decision about where the userland superblock reader
 * lives -- not something to settle inside a df port.
 *
 * The source is kept below, unbuilt and unedited, so the day that decoder is
 * shared there is nothing to re-derive.  Stated in df(1)'s BUGS.  Everything
 * `df', `df /' and `df <path>' do goes through statfs(2) and is verbatim.
 */
/*
 * Copyright (c) 1980, 1990, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
"@(#) Copyright (c) 1980, 1990, 1993, 1994\n\
	The Regents of the University of California.  All rights reserved.\n";

static char sccsid[] = "@(#)df.c	8.8 (2.11BSD) 2020/3/19";
#endif

#include <sys/param.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/file.h>

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int	 bread();
char	*getmntpt();
void	 prtstat();
void	 ufs_df();
void	 usage();

int	iflag, hflag;

int
main(argc, argv)
	int argc;
	register char *argv[];
{
	struct stat stbuf;
	struct statfs statfsbuf, *mntbuf;
	int mntsize;
	int ch, err, i, maxwidth, width;
	char *mntpt;

	while ((ch = getopt(argc, argv, "hi")) != EOF)
		switch (ch) {
		case 'h':
			hflag = 1;
			break;
		case 'i':
			iflag = 1;
			break;
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	mntsize = getmntinfo(&mntbuf, MNT_NOWAIT);
	maxwidth = 0;
	for (i = 0; i < mntsize; i++) {
		width = strlen(mntbuf[i].f_mntfromname);
		if (width > maxwidth)
			maxwidth = width;
	}

	if (!*argv) {
		for (i = 0; i < mntsize; i++)
			prtstat(&mntbuf[i], maxwidth);
		exit(0);
	}

	for (; *argv; argv++) {
		if (stat(*argv, &stbuf) < 0) {
			err = errno;
			if ((mntpt = getmntpt(*argv)) == 0) {
				warn("%s", *argv);
				continue;
			}
		} else if ((stbuf.st_mode & S_IFMT) == S_IFCHR) {
			ufs_df(*argv, maxwidth);
			continue;
		} else if ((stbuf.st_mode & S_IFMT) == S_IFBLK) {
			if ((mntpt = getmntpt(*argv)) == 0) {
				ufs_df(*argv, maxwidth);
				continue;
			}
		} else
			mntpt = *argv;
		/*
		 * Statfs does not take a `wait' flag, so we cannot
		 * implement nflag here.
		 */
		if (statfs(mntpt, &statfsbuf) < 0) {
			warn("%s", mntpt);
			continue;
		}
		if (argc == 1)
			maxwidth = strlen(statfsbuf.f_mntfromname) + 1;
		prtstat(&statfsbuf, maxwidth);
	}
	return (0);
}

char *
getmntpt(name)
	char *name;
{
	register int i;
	int mntsize;
	struct statfs *mntbuf;

	mntsize = getmntinfo(&mntbuf, MNT_NOWAIT);
	for (i = 0; i < mntsize; i++) {
		if (!strcmp(mntbuf[i].f_mntfromname, name))
			return (mntbuf[i].f_mntonname);
	}
	return (0);
}

/*
 * Convert statfs returned filesystem size into BLOCKSIZE units.
 * Attempts to avoid overflow for large filesystems.
 */
long
fsbtoblk(num, fsbs, bs)
	long	num;
	register int	fsbs, bs;
	{
	return((fsbs != 0 && fsbs < bs) ?
		num / (bs / fsbs) : (num) * (fsbs / bs));
	}

/*
 * Print out status about a filesystem.
 */
void
prtstat(sfsp, maxwidth)
	register struct statfs *sfsp;
	register int maxwidth;
{
	static int blocksize;
	static int headerlen, timesthrough;
	static char *header;
	long used, availblks;
	ino_t	inodes, iused;

	if (maxwidth < 11)
		maxwidth = 11;
	if (++timesthrough == 1) {
/*		header = getbsize(&headerlen, &blocksize); */
		if (hflag) {
			header = "Megabytes";
		} else {
			header = "1K-blocks";
		}
		blocksize = 1024;
		headerlen = 9;

		(void)printf("%-*.*s %s     Used    Avail Capacity",
		    maxwidth, maxwidth, "Filesystem", header);
		if (iflag)
			(void)printf(" iused   ifree  %%iused");
		(void)printf("  Mounted on\n");
	}
	(void)printf("%-*.*s", maxwidth, maxwidth, sfsp->f_mntfromname);
	used = sfsp->f_blocks - sfsp->f_bfree;
	availblks = sfsp->f_bavail + used;
	if (hflag) {
		(void)printf(" %*.1fM %7.1fM %7.1fM", headerlen-1,
	    	    (double)fsbtoblk(sfsp->f_blocks, sfsp->f_bsize, blocksize)/1024.0,
	    	    (double)fsbtoblk(used, sfsp->f_bsize, blocksize)/1024.0,
	    	    (double)fsbtoblk(sfsp->f_bavail, sfsp->f_bsize, blocksize)/1024.0);
        } else {
		(void)printf(" %*ld %8ld %8ld", headerlen,
	    	    fsbtoblk(sfsp->f_blocks, sfsp->f_bsize, blocksize),
	    	    fsbtoblk(used, sfsp->f_bsize, blocksize),
	    	    fsbtoblk(sfsp->f_bavail, sfsp->f_bsize, blocksize));
	}
	(void)printf(" %5.0f%%",
	    availblks == 0 ? 100.0 : (double)used / (double)availblks * 100.0);
	if (iflag) {
		inodes = sfsp->f_files;
		iused = inodes - sfsp->f_ffree;
		(void)printf(" %7u %7u %5.0f%% ", iused, sfsp->f_ffree,
		   inodes == 0 ? 100.0 : (double)iused / (double)inodes * 100.0);
	} else 
		(void)printf("  ");
	(void)printf("  %s\n", sfsp->f_mntonname);
}

/*----------------------------------------------------------------------------
 * UPSTREAM'S RAW-DEVICE HALF, KEPT VERBATIM AND NOT COMPILED.  See the header:
 * `struct fs' overlaid on disk bytes is PDP-11 byte order, and this machine is
 * not a PDP-11.  #if 0 rather than deleted so the port stays whole.
 *--------------------------------------------------------------------------*/
#if 0
/*
 * This code constitutes the pre-system call Berkeley df code for extracting
 * information from filesystem superblocks.
 */
#include <sys/fs.h>
#include <fstab.h>

union {
	struct fs fs;
	char dummy[SBSIZE];
} sb;
#define sblock sb.fs

int	rfd;

void
ufs_df(file, maxwidth)
	char *file;
	int maxwidth;
{
	struct statfs statfsbuf;
	register struct statfs *sfsp;
	register char *mntpt;
	static int synced;

	if (synced++ == 0)
		sync();

	if ((rfd = open(file, O_RDONLY)) < 0) {
		warn("%s", file);
		return;
	}
	if (bread((off_t)SBLOCK * DEV_BSIZE, &sblock, SBSIZE) == 0) {
		(void)close(rfd);
		return;
	}
	sfsp = &statfsbuf;
	sfsp->f_type = MOUNT_UFS;
	sfsp->f_flags = 0;
	sfsp->f_bsize = MAXBSIZE;
	sfsp->f_iosize = MAXBSIZE;
	sfsp->f_blocks = sblock.fs_fsize - sblock.fs_isize;
	sfsp->f_bfree = sblock.fs_tfree;
	sfsp->f_bavail = sblock.fs_tfree;
	if (sfsp->f_bavail < 0)
		sfsp->f_bavail = 0;
	sfsp->f_files =  (sblock.fs_isize - 2) * INOPB;
	sfsp->f_ffree = sblock.fs_tinode;
	sfsp->f_fsid[0] = 0;
	sfsp->f_fsid[1] = 0;
	if ((mntpt = getmntpt(file)) == 0)
		mntpt = "";
	bcopy(mntpt, &sfsp->f_mntonname[0], MNAMELEN);
	bcopy(file, &sfsp->f_mntfromname[0], MNAMELEN);
	prtstat(sfsp, maxwidth);
	(void)close(rfd);
}

int
bread(off, buf, cnt)
	off_t off;
	void *buf;
	register int cnt;
{
	register int nr;

	(void)lseek(rfd, off, L_SET);
	if ((nr = read(rfd, buf, cnt)) != cnt) {
		/* Probably a dismounted disk if errno == EIO. */
		if (errno != EIO)
			(void)fprintf(stderr, "\ndf: %ld: %s\n",
			    off, strerror(nr > 0 ? EIO : errno));
		return (0);
	}
	return (1);
}

#endif  /* the raw-device half */

/* ...and the refusal that stands in its place.  main() is VERBATIM and calls
 * ufs_df() on a character or block special, so the name has to resolve; what
 * it must not do is answer with numbers read in the wrong byte order.  It says
 * so instead, in err(3)'s voice like every other error in this program.
 *
 * warnx and not warn: there is no errno to report -- nothing was attempted. */
void
ufs_df(file, maxwidth)
	char *file;
	int maxwidth;
{
	warnx("%s: raw device statistics need a userland superblock decoder",
	    file);
}

void
usage()
{
	(void)fprintf(stderr, "usage: df [-h] [-i] [file | file_system ...]\n");
	exit(1);
}

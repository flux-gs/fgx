/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sbin/fsck/setup.c
 *   Ported from usr/sbin/fsck/setup.c, 2.11BSD.  Original work:
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if	!defined(lint) && defined(DOSCCS)
static char sccsid[] = "@(#)setup.c	5.3.1 (2.11BSD) 1996/2/3";
#endif not lint

#include <stdio.h>
#include <sys/file.h>
#include "ufsdisk.h"
#include <sys/stat.h>
#include <sys/mount.h>
#include "fsck.h"

extern void ufs_sbdecode();

setup(dev)
	char *dev;
{
	dev_t rootdev;
	off_t smapsz, totsz, lncntsz;
	daddr_t bcnt, nscrblk;
	struct stat statb;
	u_int msize;
	char *mbase;
	int i, j, n;
	long size;
	BUFAREA *bp;
	char junk[80 + sizeof (".XXXXX") + 1];

	if (stat("/", &statb) < 0)
		errexit("Can't stat root\n");
	rootdev = statb.st_dev;
	if (stat(dev, &statb) < 0) {
		printf("Can't stat %s\n", dev);
		return (0);
	}
	rawflg = 0;
	if ((statb.st_mode & S_IFMT) == S_IFBLK)
		;
	else if ((statb.st_mode & S_IFMT) == S_IFCHR)
		rawflg++;
	else {
		if (reply("file is not a block or character device; OK") == 0)
			return (0);
	}
	if (rootdev == statb.st_rdev)
		hotroot++;
	/* AND THE RAW SPELLING OF THE ROOT IS STILL THE ROOT.  Upstream's test
	 * above is a second, independent derivation of what blockcheck already
	 * worked out, and it fires because 2.11BSD's blockcheck hands the hot
	 * root's BLOCK name back.  This tree follows Reno there -- the root is
	 * checked through its raw device -- so the character device's st_rdev is
	 * a different number and the test above cannot match, and a `fsck
	 * /dev/rsd0' typed by hand reaches the passes with hotroot 0.
	 *
	 * THAT IS NOT COSMETIC.  hotroot gates update #456's clean marking
	 * ("The root filesystem is special, since it is already mounted"), the
	 * REBOOT UNIX notice, and the exit-4 that tells /etc/rc to restart.
	 * Without it, checking a mounted read-write root by its raw name stamps
	 * MNT_CLEAN on a filesystem that is being written, and the next boot
	 * skips the check on a volume nobody has checked -- the accumulating
	 * shape ufs_vfsops.c's update arm describes.
	 *
	 * The block counterpart is the name with the leading `r' dropped, which
	 * is the convention rawname/unrawname already encode; unrawname edits in
	 * place, so it gets a copy. */
	if (hotroot == 0 && rawflg) {
		static char bdev[32];   /* rawname's own buffer size for a
					 * device name, and its own reason:
					 * not on a 512-byte kernel stack */
		struct stat bstatb;
		char *unrawname();

		if (strlen(dev) < sizeof(bdev)) {
			(void)strcpy(bdev, dev);
			if (stat(unrawname(bdev), &bstatb) == 0 &&
			    rootdev == bstatb.st_rdev)
				hotroot++;
		}
	}
	if ((dfile.rfdes = open(dev, 0)) < 0) {
		printf("Can't open %s\n", dev);
		return (0);
	}
	if (preen == 0)
		printf("** %s", dev);
	if (nflag || (dfile.wfdes = open(dev, 1)) < 0) {
		dfile.wfdes = -1;
		if (preen)
			pfatal("NO WRITE ACCESS");
		printf(" (NO WRITE)");
	}
	if (preen == 0)
		printf("\n");
	dfile.mod = 0;
	lfdir = 0;
	initbarea(&sblk);
	initbarea(&fileblk);
	initbarea(&inoblk);
	/*
	 * Read in the super block and its summary info.
	 */
	/* READ THE BLOCK, THEN DECODE IT.  Upstream reads straight into
	 * `sblock' because over there the in-core superblock IS the disk
	 * bytes; ufs_fs.h argues at length why it cannot be here (32-bit fields
	 * stored high word first, and sb_volblocks not 4-aligned on disk).  The
	 * RAW block is kept in sblk.b_un.b_buf -- ufs_sbencode needs it back on
	 * the write, and fs_fsmnt is read straight out of it since the decoded
	 * form does not carry the mount name. */
	if (bread(&dfile, sblk.b_un.b_buf, SBLOCK, SBSIZE) != 0)
		return (0);
	ufs_sbdecode(sblk.b_un.b_buf, &sblock);
	sblk.b_bno = SBLOCK;
	sblk.b_size = SBSIZE;

	imax = ((ino_t)sblock.sb_isize - (SUPERB+1)) * INOPB;
	fmin = (daddr_t)sblock.sb_isize;	/* first data blk num */
	fmax = sblock.sb_volblocks;		/* first invalid blk num */
	startib = fmax;
	if(fmin >= fmax || 
		(imax/INOPB) != ((ino_t)sblock.sb_isize-(SUPERB+1))) {
		pfatal("Size check: fsize %ld isize %d",
			sblock.sb_volblocks,sblock.sb_isize);
		printf("\n");
		ckfini();
		return(0);
	}
	/* A CLEAN FILE SYSTEM IS SKIPPED, 2.11BSD update #456, and -1 is how
	 * setup says so -- 0 already means "cannot check":
	 *
	 *      if (!fflag) {
	 *              if (sblock.fs_flags & MNT_CLEAN) return(-1);
	 *              if (hotroot && (sblock.fs_flags & MNT_WASCLEAN)) return(-1);
	 *      }
	 *
	 * UPSTREAM'S SECOND TEST IS NOT CARRIED, and this is the one place this
	 * port deliberately refuses #456's own code:
	 *
	 *      if (hotroot && (sblock.fs_flags & MNT_WASCLEAN)) return(-1);
	 *
	 * MNT_WASCLEAN IS ON THE PLATTER, and it survives a reboot.  It reaches
	 * the disk on any superblock write while the volume is mounted, so a
	 * machine that mounted a clean root and then went down UNCLEANLY leaves
	 * WASCLEAN set with MNT_CLEAN gone -- and the next boot's hotroot test
	 * reads that as "it was clean at mount" and skips the check.  It is not
	 * this boot's mount it is describing; it is the last one's.
	 *
	 * MEASURED, and it is why this exists: `sync; reboot' twice left
	 * `file system is clean; not checking' on a root that had been written
	 * and never checked, and the damage compounded -- SIZE=0 FILE HAS
	 * ALLOCATED BLOCKS, PARTIALLY ALLOCATED INODE -- behind a flag saying
	 * there was nothing to look at.
	 *
	 * FGX DOES NOT NEED IT.  Upstream's test exists because a hotroot's
	 * on-disk MNT_CLEAN cannot be trusted; here the root is mounted READ-ONLY
	 * and fsck runs before /etc/rc remounts it, so the mount has written
	 * nothing and MNT_CLEAN means exactly what it says.  The cost of dropping
	 * it is that a root goes unmarked until something marks it -- see
	 * apple/fgx#403 for the reboot-time fsclean() that does.
	 *
	 * UPSTREAM ASKS THIS AT THE END OF setup AND FGX ASKS IT HERE, which is
	 * the one deliberate difference and it is not cosmetic.  Everything below
	 * sizes and claims the map arena, and that can FAIL -- a volume whose maps
	 * do not fit answers `NEED SCRATCH FILE', and a root that needs one is
	 * refused outright.  Measured: the sweep's 65536-block root wanted 50
	 * blocks of scratch, so /etc/rc's `fsck -p' exited 8 and aborted the boot
	 * on a volume that was CLEAN and should never have been read past its
	 * superblock.  Asking first costs nothing and is the same question. */
	if (!fflag && (sblock.sb_flags & MNT_CLEAN))
		return(-1);

	if (preen == 0)
		printf("File System: %.*s\n\n", MAXMNTLEN, &sblk.b_un.b_buf[SB_FSMNT]);
	/*
	 * allocate and initialize the necessary maps
	 */
	bmapsz = roundup(howmany(fmax,BITSPB),sizeof(*lncntp));
	smapsz = roundup(howmany((long)(imax+1),STATEPB),sizeof(*lncntp));
	lncntsz = (long)(imax+1) * sizeof(*lncntp);
	if(bmapsz > smapsz+lncntsz)
		smapsz = bmapsz-lncntsz;
	totsz = bmapsz+smapsz+lncntsz;

	msize = memsize;
	mbase = membase;
	bzero(mbase,msize);
	muldup = enddup = duplist;
	zlnp = zlnlist;

	if((off_t)msize < totsz) {
		bmapsz = roundup(bmapsz,DEV_BSIZE);
		smapsz = roundup(smapsz,DEV_BSIZE);
		lncntsz = roundup(lncntsz,DEV_BSIZE);
		nscrblk = (bmapsz+smapsz+lncntsz)>>DEV_BSHIFT;
		if(scrfile[0] == 0) {
			pfatal("\nNEED SCRATCH FILE (%ld BLKS)\n",nscrblk);
			do {
				printf("ENTER FILENAME:  ");
				if((n = getline(stdin, scrfile, 
						sizeof(scrfile) - 6)) == EOF)
					errexit("\n");
			} while(n == 0);
		}
		strcpy(junk, scrfile);
		strcat(junk, ".XXXXX");
		sfile.wfdes = mkstemp(junk);
		if ((sfile.wfdes < 0)
		    || ((sfile.rfdes = open(junk,0)) < 0)) {
			printf("Can't create %s\n", junk);
			ckfini();
			return(0);
		}
		unlink(junk);	/* make it invisible incase we exit */
		if (hotroot && (fstat(sfile.wfdes,&statb)==0)
		    && ((statb.st_mode & S_IFMT) == S_IFREG)
		    && (statb.st_dev==rootdev))
		     pfatal("TMP FILE (%s) ON ROOT WHEN CHECKING ROOT", junk);
		bp = &((BUFAREA *)mbase)[(msize/sizeof(BUFAREA))];
		poolhead = NULL;
		while(--bp >= (BUFAREA *)mbase) {
			initbarea(bp);
			bp->b_next = poolhead;
			poolhead = bp;
		}
		bp = poolhead;
		for(bcnt = 0; bcnt < nscrblk; bcnt++) {
			bp->b_bno = bcnt;
			dirty(bp);
			flush(&sfile,bp);
		}
		blockmap = freemap = statemap = (char *) NULL;
		lncntp = (short *) NULL;
		bmapblk = 0;
		smapblk = bmapblk + bmapsz / DEV_BSIZE;
		lncntblk = smapblk + smapsz / DEV_BSIZE;
		fmapblk = smapblk;
	}
	else {
		poolhead = NULL;
		blockmap = mbase;
		statemap = &mbase[bmapsz];
		freemap = statemap;
		lncntp = (short *)&statemap[smapsz];
	}

	return(1);
}

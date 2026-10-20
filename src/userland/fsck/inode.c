/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sbin/fsck/inode.c
 *   Ported from usr/sbin/fsck/inode.c, 2.11BSD.  Original work:
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if	!defined(lint) && defined(DOSCCS)
static char sccsid[] = "@(#)inode.c	5.2 (Berkeley) 7/17/85";
#endif not lint

#include <pwd.h>
#include "ufsdisk.h"
#include "fsck.h"

ckinode(dp, idesc)
	DINODE *dp;
	register struct inodesc *idesc;
{
	register daddr_t *ap;
	int ret, n;
	DINODE dino;

	idesc->id_fix = DONTKNOW;
	idesc->id_entryno = 0;
	idesc->id_filesize = dp->di_size;
	if (SPECIAL(dp))
		return (KEEPON);
	dino = *dp;
	for (ap = &dino.di_addr[0]; ap < &dino.di_addr[NDADDR]; ap++) {
		if (*ap == 0)
			continue;
		idesc->id_blkno = *ap;
		if (idesc->id_type == ADDR)
			ret = (*idesc->id_func)(idesc);
		else
			ret = dirscan(idesc);
		if (ret & STOP)
			return (ret);
	}
	for (ap = &dino.di_addr[NDADDR], n = 1; n <= NIADDR; ap++, n++) {
		if (*ap) {
			idesc->id_blkno = *ap;
			ret = iblock(idesc, n,
				dino.di_size - DEV_BSIZE * NDADDR);
			if (ret & STOP)
				return (ret);
		}
	}
	return (KEEPON);
}

iblock(idesc, ilevel, isize)
	struct inodesc *idesc;
	register ilevel;
	long isize;
{
	register daddr_t blk;
	int i, n, (*func)(), nif;
	extern long ufs_dget32();
	extern void ufs_dput32();
	long sizepb;
	BUFAREA ib;
	char buf[128];
	extern int pass1check(), dirscan();

	if (idesc->id_type == ADDR) {
		func = idesc->id_func;
		if (((n = (*func)(idesc)) & KEEPON) == 0)
			return (n);
	} else
		func = dirscan;
	if (outrange(idesc->id_blkno)) /* protect thyself */
		return (SKIP);
	initbarea(&ib);
	getblk(&ib, idesc->id_blkno);
	if (ib.b_errs != NULL)
		return (SKIP);
	ilevel--;
	for (sizepb = DEV_BSIZE, i = 0; i < ilevel; i++)
		sizepb *= NINDIR;
	nif = isize / sizepb + 1;
	if (nif > NINDIR)
		nif = NINDIR;
	/* AN INDIRECT BLOCK IS daddr_t's IN PDP-11 ORDER, so it is indexed
	 * rather than walked with a `daddr_t *'.  Upstream steps a pointer
	 * through the b_indir union arm, which overlays the disk bytes as this
	 * machine's longs and would read every address with its halves swapped
	 * (ufs_fs.h).  ufs_dget32/ufs_dput32 are the kernel's own accessors for
	 * these blocks -- ufs_bmap.c reads the same format through them -- and
	 * the loop bounds and the `i' that scales sizepb are unchanged. */
	if (idesc->id_func == pass1check && nif < NINDIR) {
		for (i = nif; i < NINDIR; i++) {
			if (ufs_dget32(ib.b_un.b_buf, i * 4) == 0)
				continue;
			sprintf(buf, "PARTIALLY TRUNCATED INODE I=%u",
				idesc->id_number);
			if (dofix(idesc, buf)) {
				ufs_dput32(ib.b_un.b_buf, i * 4, (daddr_t)0);
				dirty(&ib);
			}
		}
		flush(&dfile, &ib);
	}
	for (i = 1; i <= nif; i++) {
		blk = ufs_dget32(ib.b_un.b_buf, (i - 1) * 4);
		if (blk) {
			idesc->id_blkno = blk;
			if (ilevel > 0)
				n = iblock(idesc, ilevel, isize - i * sizepb);
			else
				n = (*func)(idesc);
			if (n & STOP)
				return (n);
		}
	}
	return (KEEPON);
}

DINODE *
ginode(inumber)
	register ino_t inumber;
{
	daddr_t iblk;
	register int i;
	extern void ufs_idecode();

	if (inumber < ROOTINO || inumber > imax)
		errexit("bad inode number %u to ginode\n", inumber);
	iblk = itod(inumber);
	if (iblk < startib || iblk >= startib + NINOBLK) {
		if (inoblk.b_dirty) {
			flush(&dfile, &inoblk);	/* encodes, then writes */
		}
		if (bread(&dfile, inobuf, iblk, NINOBLK * DEV_BSIZE))
			return(NULL);
		startib = iblk;
		/* Decode the whole window; fsck.h says why it is the window and
		 * not the one inode asked for. */
		for (i = 0; i < NINOBLK * INOPB; i++)
			ufs_idecode(&inobuf[i * UFS_DINODESIZE], &inocache[i]);
	}
	/* The slot within the window: whole blocks past its start, plus the
	 * inode's own offset in its block.  itoo() is 2.11BSD's, carried in
	 * ufs_fs.h. */
	return (&inocache[(int)(iblk - startib) * INOPB + itoo(inumber)]);
}

clri(idesc, s, flg)
	register struct inodesc *idesc;
	char *s;
	int flg;
{
	register DINODE *dp;

	dp = ginode(idesc->id_number);
	if (flg == 1) {
		pwarn("%s %s", s, DIRCT(dp) ? "DIR" : "FILE");
		pinode(idesc->id_number);
	}
	if (preen || reply("CLEAR") == 1) {
		if (preen)
			printf(" (CLEARED)\n");
		n_files--;
		(void)ckinode(dp, idesc);
		zapino(dp);
		setstate(idesc->id_number, USTATE);
		inodirty();
	}
}

findname(idesc)
	struct inodesc *idesc;
{
	register DIRECT *dirp = idesc->id_dirp;

	if (dirp->d_ino != idesc->id_parent)
		return (KEEPON);
	bcopy(dirp->d_name, idesc->id_name, dirp->d_namlen + 1);
	return (STOP);
}

findino(idesc)
	struct inodesc *idesc;
{
	register DIRECT *dirp = idesc->id_dirp;

	if (dirp->d_ino == 0)
		return (KEEPON);
	if (strcmp(dirp->d_name, idesc->id_name) == 0 &&
	    dirp->d_ino >= ROOTINO && dirp->d_ino <= imax) {
		idesc->id_parent = dirp->d_ino;
		return (STOP);
	}
	return (KEEPON);
}

pinode(ino)
	ino_t ino;
{
	register DINODE *dp;
	register char *p;
	struct passwd *pw;
	char *ctime();

	printf(" I=%u ", ino);
	if (ino < ROOTINO || ino > imax)
		return;
	dp = ginode(ino);
	printf(" OWNER=");
	if ((pw = getpwuid((int)dp->di_uid)) != 0)
		printf("%s ", pw->pw_name);
	else
		printf("%u ", dp->di_uid);
	printf("MODE=%o\n", dp->di_mode);
	if (preen)
		printf("%s: ", devname);
	printf("SIZE=%ld ", dp->di_size);
	p = ctime(&dp->di_mtime);
	printf("MTIME=%12.12s %4.4s ", p+4, p+20);
}

blkerr(ino, s, blk)
	ino_t ino;
	char *s;
	daddr_t blk;
{

	pfatal("%ld %s I=%u", blk, s, ino);
	printf("\n");
	switch (getstate(ino)) {

	case FSTATE:
		setstate(ino, FCLEAR);
		return;

	case DSTATE:
		setstate(ino, DCLEAR);
		return;

	case FCLEAR:
	case DCLEAR:
		return;

	default:
		errexit("BAD STATE %d TO BLKERR", getstate(ino));
		/* NOTREACHED */
	}
}

/*
 * allocate an unused inode
 */
ino_t
allocino(request, type)
	ino_t request;
	int type;
{
	register ino_t ino;
	register DINODE *dp;

	if (request == 0)
		request = ROOTINO;
	else if (getstate(request) != USTATE)
		return (0);
	for (ino = request; ino < imax; ino++)
		if (getstate(ino) == USTATE)
			break;
	if (ino == imax)
		return (0);
	switch (type & IFMT) {
	case IFDIR:
		setstate(ino, DSTATE);
		break;
	case IFREG:
	case IFLNK:
		setstate(ino, FSTATE);
		break;
	default:
		return (0);
	}
	dp = ginode(ino);
	dp->di_addr[0] = allocblk();
	if (dp->di_addr[0] == 0) {
		setstate(ino, USTATE);
		return (0);
	}
	dp->di_mode = type;
	time(&dp->di_atime);
	dp->di_mtime = dp->di_ctime = dp->di_atime;
	dp->di_size = DEV_BSIZE;
	n_files++;
	inodirty();
	return (ino);
}

/*
 * deallocate an inode
 */
freeino(ino)
	ino_t ino;
{
	struct inodesc idesc;
	extern int pass4check();
	DINODE *dp;

	bzero((char *)&idesc, sizeof(struct inodesc));
	idesc.id_type = ADDR;
	idesc.id_func = pass4check;
	idesc.id_number = ino;
	dp = ginode(ino);
	(void)ckinode(dp, &idesc);
	zapino(dp);
	inodirty();
	setstate(ino, USTATE);
	n_files--;
}

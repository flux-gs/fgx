/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sbin/fsck/fsck.h
 *   Ported from usr/sbin/fsck/fsck.h, 2.11BSD.  Original work:
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 */
/* globals.c -- the definitions behind fsck.h's declarations.  UFS 2.1.
 *
 * THIS FILE HAS NO UPSTREAM COUNTERPART, and the reason is the linker rather
 * than a design preference.  2.11BSD's fsck.h declares its ~47 shared globals
 * as TENTATIVE DEFINITIONS -- `char preen;', not `extern char preen;' -- in a
 * header included by all eleven translation units.  That is legal K&R and
 * links because the PDP-11 toolchain merges COMMON symbols: eleven tentative
 * definitions of `preen' become one.
 *
 * fcc has no common-symbol model.  MEASURED, not assumed: two TUs including
 * one header with `int g1;' in it each emit `g1 DS 2' into their own data
 * segment, and Merlin32 then has two definitions of the same label.  So the
 * header keeps the declarations and this file keeps the definitions, which is
 * the arrangement upstream already uses for its multi-TU games -- robots(6)
 * ships an extern.c for exactly this, and src/userland/robots/extern.c is its
 * port.  The transformation was mechanical: every object declaration in
 * fsck.h gained an `extern', and the same lines, verbatim and in order, are
 * below.  Nothing was retyped.
 *
 * TWO OF THE 49 ARE DELIBERATELY ABSENT.  `endpathname' and `lfname' are
 * declared in fsck.h AND defined with initialisers in dir.c:19-20 -- under
 * common-symbol linking the initialised definition simply wins, so upstream
 * never had to notice.  Defining them here as well would be a duplicate
 * symbol, so dir.c keeps them and fsck.h now declares them extern.
 */

#include "ufsdisk.h"
#include "fsck.h"

BUFAREA	inoblk;			/* inode blocks */
BUFAREA	fileblk;		/* other blks in filesys */
BUFAREA	sblk;			/* file system superblock */
BUFAREA	*poolhead;		/* ptr to first buffer in pool */
struct filecntl dfile, sfile;
daddr_t duplist[DUPTBLSIZE];	/* head of dup list */
daddr_t *enddup;			/* next entry in dup table */
daddr_t	*muldup;		/* multiple dups part of table */
ino_t	zlnlist[MAXLNCNT];	/* zero link count table */
ino_t	*zlnp;
char	inobuf[NINOBLK * DEV_BSIZE];	/* the raw window; fsck.h says why */
DINODE	inocache[NINOBLK * INOPB];	/* and its decoded form */
daddr_t	startib;
unsigned int memsize;
char	rawflg;
char	*devname;
char	nflag;			/* assume a no response */
char	yflag;			/* assume a yes response */
char	sflag;			/* rebuild free list */
int	debug;			/* output debugging info */
char	fflag;			/* force check on a clean file system (#456) */
char	noflag;			/* some question was answered `no' (#456) */
char	preen;			/* just fix normal inconsistencies */
char	hotroot;		/* checking root device */
char	fixfree;		/* force rebuild of freelist */
char	*membase;		/* base of memory we get */
char	*blockmap;		/* ptr to primary blk allocation map */
char	*freemap;		/* ptr to secondary blk allocation map */
char	*statemap;		/* ptr to inode state table */
short	*lncntp;		/* ptr to link count table */
char	pathname[MAXPATHLEN];	/* current pathname */
char	scrfile[80];		/* scratchfile name */
int	cylsize;		/* num blocks per cylinder */
int	stepsize;		/* num blocks for spacing purposes */
char	*pathp;			/* pointer to pathname position */
daddr_t	fmin;			/* block number of the first data block */
daddr_t	fmax;			/* number of blocks in the volume */
ino_t	imax;			/* number of inodes */
ino_t	lastino;		/* hiwater mark of inodes */
ino_t	lfdir;			/* lost & found directory inode number */
off_t	bmapsz;			/* num chars in blockmap */
daddr_t	bmapblk;		/* starting blk of block map */
daddr_t	smapblk;		/* starting blk of state map */
daddr_t	lncntblk;		/* starting blk of link cnt table */
daddr_t	fmapblk;		/* starting blk of free map */
daddr_t	n_blks;			/* number of blocks used */
daddr_t	n_files;		/* number of files seen */
daddr_t	n_free;			/* number of free blocks */
int	badblk, dupblk;
struct	dinode	zino;

/* The two that stopped being union arms at UFS 2.1; fsck.h says why. */
struct ufs_sb    sblock;
struct ufs_sb    freeblk;

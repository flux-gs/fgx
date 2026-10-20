/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sbin/fsck/fsck.h
 *   Ported from usr/sbin/fsck/fsck.h, 2.11BSD.  Original work:
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 *
 *	@(#)fsck.h	5.1 (Berkeley) 6/5/85
 */

#define	MAXDUP		10	/* limit on dup blks (per inode) */
#define	MAXBAD		10	/* limit on bad blks (per inode) */

#define	STEPSIZE	7	/* default step for freelist spacing */
#define	CYLSIZE		400	/* default cyl size for spacing */
#define	MAXCYL		500	/* maximum cylinder size */

/* DECLARATIONS ARE NOT OPTIONAL HERE, AND K&R'S IMPLICIT `int' IS WHY.
 * Upstream calls sbrk(), strcpy() and strcat() with no declaration in scope,
 * which is harmless on a PDP-11: an undeclared function returns int, an int is
 * 16 bits, and so is a pointer.  On the 65816 a pointer is a 32-bit FAR
 * pointer, so the implicit int TRUNCATES THE BANK and the caller gets an
 * address in bank 0 that was never allocated to it.
 *
 * Measured, not deduced: `membase = (char *)sbrk(memsize)' came back as
 * 0x5d005d -- the low word duplicated into the high -- and setup()'s
 * `bzero(mbase, msize)' then wrote 8 KB over the data bank, including fcc's
 * frame cells, so setup never returned to its caller.  fsck ran, printed the
 * superblock it had correctly decoded, and vanished with no diagnostic.
 *
 * fcc WARNS about every one of these ("implicit declaration of 'sbrk' (int
 * return assumed; a far-pointer return loses its bank)").  On this platform
 * that warning is a defect report for any function returning a pointer.
 */
#include <string.h>
#include <unistd.h>

typedef	int	(*SIG_TYP)();

#ifndef BUFSIZ
#define BUFSIZ 1024
#endif

#define	USTATE	01		/* inode not allocated */
#define	FSTATE	02		/* inode is file */
#define	DSTATE	03		/* inode is directory */
#define	DFOUND	04		/* directory found during descent */
#define	DCLEAR	05		/* directory is to be cleared */
#define	FCLEAR	06		/* file is to be cleared */

#define BITSPB	8		/* number bits per byte */
#define BITSHIFT	3	/* log2(BITSPB) */
#define BITMASK	07		/* BITSPB-1 */
#define LSTATE	4		/* bits per inode state */
#define STATEPB	(BITSPB/LSTATE)	/* inode states per byte */
#define SMASK	017		/* mask for inode state */

typedef struct dinode	DINODE;
typedef struct direct	DIRECT;

#define	ALLOC(dip)	(((dip)->di_mode & IFMT) != 0)
#define	DIRCT(dip)	(((dip)->di_mode & IFMT) == IFDIR)
#define	SPECIAL(dip) \
	(((dip)->di_mode & IFMT) == IFBLK || ((dip)->di_mode & IFMT) == IFCHR)

#define	MAXNINDIR	(MAXBSIZE / sizeof (daddr_t))
#define	MAXINOPB	(MAXBSIZE / sizeof (struct dinode))
#define	SPERB		(MAXBSIZE / sizeof(short))

/* THE UNION LOST FOUR OF ITS SIX ARMS, and the reason is the 65816 rather than
 * disuse.  Upstream's b_fs, b_fb, b_indir and b_dinode are OVERLAYS: they read
 * a block straight off a PDP-11 volume as if its bytes were this machine's
 * structures.  They are not.  A 32-bit value is stored HIGH WORD FIRST on that
 * volume, and its longs are not 4-aligned -- src/kernel/vfs/ufs_fs.h argues
 * both at length, and the kernel reads the same format through a decode for
 * exactly this reason.  So the raw block stays and the typed views go:
 *
 *   b_fs      -> `sblock', a decoded `struct ufs_sb', filled by ufs_sbdecode
 *   b_fb      -> `freeblk', decoded by fsck_fbdecode (pass5.c)
 *   b_indir   -> ufs_dget32(bp->b_un.b_buf, i * 4), in inode.c
 *   b_dinode  -> never used by upstream fsck; ginode() reads inobuf directly
 *
 * b_lnks SURVIVES, and it is worth saying why it may: those are fsck's OWN
 * link counts in its OWN scratch file, written and read by this program on
 * this machine.  Nothing about them is on-disk format. */
struct bufarea {
	struct bufarea	*b_next;		/* must be first */
	daddr_t	b_bno;
	int	b_size;
	int	b_errs;
	union {
		char	b_buf[MAXBSIZE];	/* buffer space */
		short	b_lnks[SPERB];		/* link counts */
	} b_un;
	char	b_dirty;
};

typedef struct bufarea BUFAREA;

extern BUFAREA	inoblk;			/* inode blocks */
extern BUFAREA	fileblk;		/* other blks in filesys */
extern BUFAREA	sblk;			/* file system superblock */
extern BUFAREA	*poolhead;		/* ptr to first buffer in pool */

#define	initbarea(x)	(x)->b_dirty = 0;(x)->b_bno = (daddr_t)-1
#define	dirty(x)	(x)->b_dirty = 1
#define	inodirty()	inoblk.b_dirty = 1
#define	fbdirty()	fileblk.b_dirty = 1
#define	sbdirty()	sblk.b_dirty = 1

#define	dirblk		fileblk.b_un

/* `sblock' and `freeblk' WERE MACROS ONTO THE UNION and are objects now, for
 * the reason the union comment gives.  sblk.b_un.b_buf still holds the raw
 * superblock block -- setup() decodes out of it, and ufs_sbencode needs it
 * back because it updates in place (it must: the decoded form does not carry
 * fs_fsmnt, so encoding into a scratch buffer would erase the mount name). */
extern struct ufs_sb	sblock;

/* `freeblk' IS A struct ufs_sb, AND THAT IS UPSTREAM'S PUN MADE EXPLICIT.
 * 2.11BSD's chain block is a count followed by NICFREE addresses -- the same
 * shape as the superblock's fs_nfree/fs_free pair -- and its balloc exploits
 * that literally: `*((FBLKP)&fs->fs_nfree) = *fbp'.  ufs_fs.h records the pun
 * and ufs_sb.c's ufs_fblkdecode/ufs_fblkencode take a `struct ufs_sb *' for
 * the same reason, reading and writing only those two fields.
 *
 * So fsck uses the kernel's pair rather than a private struct and a private
 * codec.  A second implementation of this format in the tree is exactly what
 * the campaign's goal 2 is a claim against. */
extern struct ufs_sb	freeblk;
#define	df_nfree	sb_nfree
#define	df_free		sb_free

struct filecntl {
	int	rfdes;
	int	wfdes;
	int	mod;
};
extern struct filecntl dfile, sfile;

enum fixstate {DONTKNOW, NOFIX, FIX};

struct inodesc {
	enum fixstate id_fix;	/* policy on fixing errors */
	int (*id_func)();	/* function to be applied to blocks of inode */
	ino_t id_number;	/* inode number described */
	ino_t id_parent;	/* for DATA nodes, their parent */
	daddr_t id_blkno;	/* current block number being examined */
	long id_filesize;	/* for DATA nodes, the size of the directory */
	off_t id_loc;		/* for DATA nodes, current location in dir */
	u_long id_entryno;	/* for DATA nodes, current entry number */
	DIRECT *id_dirp;	/* for DATA nodes, ptr to current entry */
	char *id_name;		/* for DATA nodes, name to find or enter */
	char id_type;		/* type of descriptor, DATA or ADDR */
};
/* file types */
#define	DATA	1
#define	ADDR	2

/*
 * Linked list of duplicate blocks.
 * 
 * The list is composed of two parts. The first part of the
 * list (from duplist through the node pointed to by muldup)
 * contains a single copy of each duplicate block that has been 
 * found. The second part of the list (from muldup to the end)
 * contains duplicate blocks that have been found more than once.
 * To check if a block has been found as a duplicate it is only
 * necessary to search from duplist through muldup. To find the 
 * total number of times that a block has been found as a duplicate
 * the entire list must be searched for occurences of the block
 * in question. The following diagram shows a sample list where
 * w (found twice), x (found once), y (found three times), and z
 * (found once) are duplicate block numbers:
 *
 *    w -> y -> x -> z -> y -> w -> y
 *    ^		     ^
 *    |		     |
 * duplist	  muldup
 */

#define	DUPTBLSIZE	100

extern daddr_t duplist[DUPTBLSIZE];	/* head of dup list */
extern daddr_t *enddup;			/* next entry in dup table */
extern daddr_t	*muldup;		/* multiple dups part of table */

/*
 * List of inodes with zero link counts.
 */

#define	MAXLNCNT	50

extern ino_t	zlnlist[MAXLNCNT];	/* zero link count table */
extern ino_t	*zlnp;

/* MAXDATA is the data segment's ceiling, and it is upstream's own name for
 * upstream's own constant: 2.11BSD's fsck.h hardcodes 56 KB because a segment
 * ceiling is a property of the machine.  What makes it 56 and not 64 is the
 * STACK, and FGX's bank has the same problem in the same shape.
 *
 * fsck's frames are on the bank-0 stack (its FGX2 header asks for no
 * soft-frame bank), so nothing shares the data bank with the heap; the KERNEL
 * enforces the bank's HEAP_LIM cell ($FFF8), which protects the heap
 * descriptor above it.  The reservation below is upstream's number, kept so
 * the arena's arithmetic matches upstream's.
 *
 * 8 KB is upstream's reservation (64 - 56), kept for the reason upstream keeps
 * it: it is not derived from anything, it is the number that has been enough.
 *
 * IT IS A CEILING AND NOTHING MORE: whether the break can actually reach it is
 * sbrk's answer, and main()'s back-off loop is what asks. */
#define	STKRESERVE	((unsigned)8 * 1024)
#define	MAXDATA	((unsigned)0xFFFA - STKRESERVE)
/* THE ARENA IS NO LONGER A CONSTANT.  main() computes it upstream's way --
 * everything between the current break and MAXDATA, then backs off MEMUNIT at
 * a time until sbrk agrees -- so it tracks this program's own data size
 * instead of being a number retuned whenever the bss moves.  What follows is
 * why the size matters at all.
 *
 * A SCRATCH FILE IS NEEDED ONLY WHEN THE MAPS DO NOT FIT (setup.c:123).  That
 * is the whole rule, and for every volume but one it is a question of speed.
 * The exception is the root, and 2.11BSD's own rc states it directly, above
 * the line this arena exists to serve:
 *
 *     # this will *only* work if fsck can do your root file system
 *     # without a temporary file, and if the root file system is
 *     # checked alone in a pass by itself -- be careful!  This can
 *     # *seriously* mess you up.
 *     fsck -p -t /_FSCK_TMP_FILE
 *
 * -- usr/etc/rc:36-40.  The `-t' path is ON THE ROOT, so a root that needs a
 * scratch file gets one on the filesystem being checked, and setup() refuses
 * exactly that:
 *
 *     if (hotroot && (fstat(sfile.wfdes,&statb)==0)
 *         && ((statb.st_mode & S_IFMT) == S_IFREG)
 *         && (statb.st_dev==rootdev))
 *          pfatal("TMP FILE (%s) ON ROOT WHEN CHECKING ROOT", junk);
 *
 * and pfatal under -p prints UNEXPECTED INCONSISTENCY and exit(8)s.  The third
 * clause is the one that matters: it is the file's LOCATION that is refused,
 * not the scratch path as such.  Give rc a `-t' on another filesystem -- a
 * mounted ramdisk -- and the root could use one.  Making the maps fit is the
 * simpler half of that choice and the one upstream's comment assumes, so
 * sizing this is a correctness question for /etc/rc rather than a speed one.
 *
 * The maps are howmany(fmax,8) of block map, howmany(imax+1,2) of state map
 * and 2*(imax+1) of link counts.  MEASURED on this build's 32000-block root
 * (8000 inodes): 24,004 bytes, against the ~34 KB the arena comes to.  They
 * fit, and the check then runs clean -- five phases, no scratch file, no
 * UNREF, on a live read-write root.
 *
 * At 8192 it did not fit, and what that cost was not just a scratch file: the
 * file itself became the fault the same run reported.  `UNREF FILE I=566
 * SIZE=24576', ALLOCATED INODE(S) IN IFREE LIST, 25 DUP BLKS IN FREE LIST and
 * BAD FREE LIST all appeared, and all of them were fsck's own 24 blocks.
 *
 * THE SCRATCH PATH IS KEPT, not deleted: it is what lets fsck check a volume
 * bigger than memory, and that is the day you need it.  A root bigger than
 * this arena can still be checked by hand with a `-t' that is not on it. */
#define	MEMUNIT	64
#define	NINOBLK	4		/* number of blocks of inodes to read at once */

/* THE INODE WINDOW IS RAW DISK BYTES AND inocache IS ITS DECODED FORM.
 * Upstream sizes inobuf as NINOBLK*INOPB*sizeof(struct dinode) and hands out
 * pointers INTO it, because on a PDP-11 the on-disk inode IS a struct dinode.
 * Here it is not -- 32-bit fields are stored high word first (ufs_fs.h) -- so
 * the window is NINOBLK*DEV_BSIZE bytes of disk, spelled in DISK units rather
 * than in this compiler's sizeof, and ginode returns a pointer into the
 * decoded array beside it.
 *
 * DECODED AS A WHOLE WINDOW, NOT ONE INODE AT A TIME, and that is upstream's
 * semantics rather than convenience: ginode's callers may hold two DINODE
 * pointers at once, and they rely on a pointer staying valid while other
 * inodes in the same window are fetched.  A single decoded slot would alias
 * them together.  What upstream does NOT promise is that a pointer survives
 * the window SLIDING -- linkup re-fetches after every descent (dir.c:358,
 * :386) for exactly that reason -- so the cache tracks the window and no more.
 *
 * flush() encodes the cache back before the write; it is the only writer. */
extern char	inobuf[NINOBLK * DEV_BSIZE];	/* the window, as disk bytes */
extern DINODE	inocache[NINOBLK * INOPB];	/* the same window, decoded */
extern daddr_t	startib;

extern unsigned int memsize;
extern char	rawflg;
extern char	*devname;
extern char	nflag;			/* assume a no response */
extern char	yflag;			/* assume a yes response */
extern char	sflag;			/* rebuild free list */
extern int	debug;			/* output debugging info */
extern char	fflag;			/* force check on a clean file system (#456) */
extern char	noflag;			/* some question was answered `no' (#456) --
					 * so the volume is NOT clean, whatever
					 * else the check found */
extern char	preen;			/* just fix normal inconsistencies */
extern char	hotroot;		/* checking root device */
extern char	fixfree;		/* force rebuild of freelist */
extern char	*membase;		/* base of memory we get */

extern char	*blockmap;		/* ptr to primary blk allocation map */
extern char	*freemap;		/* ptr to secondary blk allocation map */
extern char	*statemap;		/* ptr to inode state table */
extern short	*lncntp;		/* ptr to link count table */

extern char	pathname[MAXPATHLEN];	/* current pathname */
extern char	scrfile[80];		/* scratchfile name */
extern int	cylsize;		/* num blocks per cylinder */
extern int	stepsize;		/* num blocks for spacing purposes */
extern char	*pathp;			/* pointer to pathname position */
extern char	*endpathname;

extern daddr_t	fmin;			/* block number of the first data block */
extern daddr_t	fmax;			/* number of blocks in the volume */
extern ino_t	imax;			/* number of inodes */
extern ino_t	lastino;		/* hiwater mark of inodes */
extern ino_t	lfdir;			/* lost & found directory inode number */
extern char	*lfname;		/* lost & found directory name */

extern off_t	bmapsz;			/* num chars in blockmap */
extern daddr_t	bmapblk;		/* starting blk of block map */
extern daddr_t	smapblk;		/* starting blk of state map */
extern daddr_t	lncntblk;		/* starting blk of link cnt table */
extern daddr_t	fmapblk;		/* starting blk of free map */

extern daddr_t	n_blks;			/* number of blocks used */
extern daddr_t	n_files;		/* number of files seen */
extern daddr_t	n_free;			/* number of free blocks */
extern int	badblk, dupblk;

#define	outrange(x)	(x < fmin || x >= fmax)
#define	zapino(x)	(*(x) = zino)
extern struct	dinode	zino;

#define setlncnt(x,n)	dolncnt(x,0,n)
#define getlncnt(x)	dolncnt(x,1,0)
#define declncnt(x)	dolncnt(x,2,0)
#define	inclncnt(x)	dolncnt(x,3,0)

#define setbmap(x)	domap(x,0)
#define getbmap(x)	domap(x,1)
#define clrbmap(x)	domap(x,2)

#define setfmap(x)	domap(x,0+4)
#define getfmap(x)	domap(x,1+4)
#define clrfmap(x)	domap(x,2+4)

#define setstate(x,y)	dostate(x,y,0)
#define getstate(x)	dostate(x,0,1)

#define	ALTERED	010
#define	KEEPON	04
#define	SKIP	02
#define	STOP	01

time_t	time();
DINODE	*ginode();
BUFAREA	*getblk();
int	findino();
daddr_t	allocblk();

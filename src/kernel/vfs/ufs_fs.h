/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/fs.h
 *   Ported from usr/sys/h/fs.h, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* ufs_fs.h -- the on-disk superblock.  UFS 1.10a.
 *
 * THE FORMAT IS 2.11BSD's AND THE ARCHITECTURE AROUND IT IS RENO's, which is
 * the campaign's standing split and is nowhere more dangerous than here.  Reno
 * has a `struct fs` too and it is a COMPLETELY DIFFERENT STRUCTURE -- FFS,
 * with cylinder groups and fragments.  The two share field names and share
 * almost no meanings.
 *
 *============================================================================
 * THE FIELD-NAME FIREWALL, AND WHY EVERY NAME BELOW IS DELIBERATELY WRONG.
 *
 * The campaign plan makes this mandatory and states the reason in one line:
 *
 *     fs_fsize means the FRAGMENT SIZE in Reno and the TOTAL VOLUME SIZE IN
 *     BLOCKS in 2.11BSD.  Code ported between the two compiles clean and
 *     silently does something else.
 *
 * Reno's ufs code is full of `fs->fs_fsize`, and every one of those uses means
 * "how big is a fragment".  Ported against a structure where that name holds
 * the volume size, it computes garbage that is the right TYPE, in the right
 * UNITS-looking magnitude, and wrong -- the compiler cannot help, and neither
 * can a test that does not happen to span the difference.
 *
 * So NOTHING here is called fs_*.  The prefix is sb_, the type is `struct
 * ufs_sb`, and the one genuinely treacherous field is renamed to say what it
 * is: sb_volblocks, not sb_fsize.  A line of Reno code that reaches for
 * fs_fsize does not compile against this header, which is the entire point --
 * the firewall is a COMPILE error where the alternative is a runtime lie.
 *
 *============================================================================
 * THIS IS THE IN-CORE FORM, DECODED -- IT IS NOT AN OVERLAY.
 *
 * Two independent reasons it cannot be a struct laid over the disk bytes:
 *
 *   LONGS ARE NOT 4-ALIGNED ON DISK.  sb_volblocks sits at byte offset 2, and
 *   the plan calls that out as the load-bearing case.  fcc is free to align a
 *   long in a struct; the PDP-11 image does not.
 *
 *   THE BYTE ORDER IS NOT THIS MACHINE'S.  A 32-bit value stores HIGH WORD
 *   FIRST, little-endian within each word: 0x01020304 is the bytes 02 01 04
 *   03.  MEASURED on the real machine (kernel #18, 2026-08-09), not inferred
 *   from headers -- see tools/fgxfs.py, which reads real volumes with it.  A
 *   16-bit field therefore overlays a 65816 directly and every 32-bit field
 *   needs a half-swap, which is what ufs_sbdecode does.
 *
 * The SB_* offsets below are the on-disk ones, and they are the same numbers
 * tools/fgxfs.py uses -- that tool is an INDEPENDENT implementation of this
 * format and the probe checks this decoder against volumes it wrote.  Two
 * implementations agreeing is evidence; one agreeing with itself is not.
 */

#ifndef _FGX_UFS_FS_H_
#define _FGX_UFS_FS_H_

#include "fsparam.h"

/* Geometry, from 2.11BSD's h/fs.h and h/param.h.  FS_BLKSIZE (fsparam.h) is
 * the filesystem block and is 1024, which is 2.11BSD's DEV_BSIZE -- the name
 * differs because FGX's DEVICE sector is 512 and calling both DEV_BSIZE is how
 * the two get confused.  fsbtodb(b) is b << 1. */
#define NICFREE         50      /* daddr_t cached in the superblock free list */
#define NICINOD         100     /* ino_t cached in the superblock inode list */
#define INOPB           16      /* dinodes per filesystem block */
#define UFS_ROOTINO     2       /* the root's inode number */
#define UFS_SBLOCK      1       /* the superblock's filesystem block */
#define MAXMNTLEN       12      /* sb_fsmnt, on disk */
#define UFS_DINODESIZE  64      /* bytes per on-disk inode; see inode.h */

/* THE INDIRECT-BLOCK GEOMETRY, from 2.11BSD h/fs.h:114-118.  An indirect block
 * is FS_BLKSIZE of nothing but daddr_t, so NINDIR is 1024/4 = 256, and because
 * that is a power of two the level arithmetic can be a shift and a mask rather
 * than a divide and a modulo.
 *
 * THAT CHOICE IS NOT COSMETIC HERE.  4.3BSD-Reno's bmap writes the same
 * arithmetic as `sh /= NINDIR(fs)` and `i = (bn / sh) % NINDIR(fs)`, because on
 * a VAX a 32-bit divide is one instruction.  fcc has no such instruction and
 * calls a runtime helper for every one of them, on a path taken once per level
 * per block read.  2.11BSD's own form is the shift, and it is exact rather than
 * approximate -- so this port takes Reno's STRUCTURE and 2.11BSD's ARITHMETIC,
 * which is the campaign's standing split applied to a single function. */
#define NINDIR          256     /* daddr_t per indirect block: FS_BLKSIZE / 4 */
#define NSHIFT          8       /* log2(NINDIR) */
#define NMASK           255     /* NINDIR - 1 */
#define NDADDR          4       /* direct blocks in di_addr */
#define NIADDR          3       /* indirect blocks in di_addr (single/dbl/trpl) */

/* itod/itoo -- inode number to its i-list block, and to its slot within it.
 * Verbatim from 2.11BSD h/fs.h:87-88, parenthesised the same way:
 *
 *     #define itoo(x)  ((int)(((x) + 2 * INOPB - 1) % INOPB))
 *     #define itod(x)  ((daddr_t)((((u_int)(x) + 2 * INOPB - 1) / INOPB)))
 *
 * The `+ 2 * INOPB - 1` is not a rounding term.  It is the i-list's OFFSET: the
 * list starts at block 2 (block 0 boot, block 1 superblock) and inode 0 does
 * not exist, so inode 1 is the first slot of block 2.  itod(1) is 2. */
#define itoo(x)         ((int)(((x) + 2 * INOPB - 1) % INOPB))
#define itod(x)         ((daddr_t)(((unsigned)(x) + 2 * INOPB - 1) / INOPB))

/* ON-DISK OFFSETS into the superblock block.  Byte offsets, not indices, and
 * deliberately not derived from sizeof() anything: the layout is the PDP-11's
 * and this machine's compiler must not get a vote. */
#define SB_ISIZE        0       /* u_short: first block after the i-list */
#define SB_VOLBLOCKS    2       /* daddr_t: blocks in the entire volume */
#define SB_NFREE        6       /* short */
#define SB_FREE         8       /* daddr_t[NICFREE] */
#define SB_NINODE       208     /* short */
#define SB_INODE        210     /* ino_t[NICINOD] */
#define SB_FLOCK        410     /* char */
#define SB_FMOD         411     /* char */
#define SB_ILOCK        412     /* char */
#define SB_RONLY        413     /* char */
#define SB_TIME         414     /* time_t */
#define SB_TFREE        418     /* daddr_t: total free blocks */
#define SB_TINODE       422     /* ino_t:   total free inodes */
#define SB_STEP         424     /* short */
#define SB_CYL          426     /* short */
#define SB_FSMNT        428     /* char[MAXMNTLEN] */
#define SB_LASTI        440     /* ino_t */
#define SB_NBEHIND      442     /* ino_t */
#define SB_FLAGS        444     /* u_short */
#define SB_ONDISK_SIZE  446     /* sizeof(struct fs) on the PDP-11, measured */

/* THE CHAIN BLOCK (2.11BSD `struct fblk`, h/fs.h:70-73).
 *
 * The superblock caches NICFREE addresses.  When they run out, the LAST one
 * taken is not an ordinary block: it holds the next batch, as a count followed
 * by NICFREE more addresses.  So a chain block is simultaneously ON the free
 * list and the container FOR the rest of it, and its contents matter only
 * until it is handed out.  fs_free[0] == 0 terminates the whole chain.
 *
 * On the PDP-11 the two are the same bytes -- 2.11BSD's balloc does
 * `*((FBLKP)&fs->fs_nfree) = *fbp`, punning the superblock's own nfree/free
 * pair onto the block it just read, and `free()` punts the other way.  THAT
 * PUN IS NOT AVAILABLE HERE and its absence is the point of the decoded form:
 * our in-core sb_free[] is native 32-bit longs in this machine's byte order,
 * the disk's is PDP-11 order, so the transfer has to go through the same
 * half-swap as every other long.  ufs_fblkdecode/ufs_fblkencode are that
 * transfer written out, which is why they exist at all. */
#define FBLK_NFREE      0       /* short: entries live in df_free */
#define FBLK_FREE       2       /* daddr_t[NICFREE] */

/* The in-core superblock.
 *
 * THE CACHED FREE LISTS ARRIVED AT 1.10b, and 1.10a's note explaining their
 * absence -- "400 bytes per mount of state nothing consults" -- is now
 * answered rather than merely superseded: ufs_alloc.c consults them, and it is
 * the only thing that does.  They are 400 of this structure's ~460 bytes, so
 * `struct ufs_sb` is no longer something to put on a stack.  vfs_probe.c holds
 * its copy STATIC for exactly that reason, and 1.8's `struct mount` will hold
 * the real one on the heap.
 *
 * sb_lasti/sb_nbehind came with them.  They are ialloc's circular-search state
 * -- where the last i-list scan stopped, and an estimate of how many free
 * inodes lie BEHIND that point -- and they live on disk (SB_LASTI, SB_NBEHIND)
 * because the estimate is worth keeping across a mount.
 *
 * sb_flock/sb_ilock are the on-disk serialisation bytes, and since 1.10b they
 * are HONOURED rather than merely read: ufs_balloc and ufs_ialloc set them
 * across the window where they do I/O and the in-core lists are inconsistent,
 * and sleep on them if they find one set.  2.11BSD's h/fs.h notes both "MUST
 * be on an even byte boundary because they are used as sleep() channels and
 * odd values specify a network sleep" -- a PDP-11 constraint with no meaning
 * here, recorded because it explains the field order upstream and not this
 * one.  sb_ronly is still read and not honoured; the mount that enforces it is
 * 1.8's. */
struct ufs_sb {
    unsigned short  sb_isize;       /* 2.11BSD fs_isize: 1st block past i-list */
    daddr_t         sb_volblocks;   /* 2.11BSD fs_fsize -- SEE THE FIREWALL */
    short           sb_nfree;       /* entries live in the on-disk free cache */
    daddr_t         sb_free[NICFREE];   /* 2.11BSD fs_free: the block cache */
    short           sb_ninode;      /* entries live in the on-disk inode cache */
    ino_t           sb_inode[NICINOD];  /* 2.11BSD fs_inode: the inode cache */
    long            sb_time;        /* 2.11BSD fs_time: last superblock update */
    daddr_t         sb_tfree;       /* 2.11BSD fs_tfree: total free blocks */
    unsigned short  sb_tinode;      /* 2.11BSD fs_tinode: total free inodes */
    short           sb_step;        /* free-list rotational step */
    short           sb_cyl;         /* blocks per rotational pattern */
    ino_t           sb_lasti;       /* ialloc's circular-search restart point */
    ino_t           sb_nbehind;     /* est. free inodes before sb_lasti */
    /* 2.11BSD fs_flags: mount-time flags.  FGX WRITES ZERO, AND ZERO IS THE
     * CORRECT VALUE -- it means "not clean", which asks fsck to check the
     * volume rather than skip it.
     *
     * The vendored tree does not name what today's 2.11BSD puts here.  Patch
     * 456 ("filesystem clean", Johnny Billquist) added MNT_CLEAN 0x2000 -- the
     * file system is clean -- and MNT_WASCLEAN 0x4000 -- it was clean at mount.
     * So a volume the live machine has unmounted cleanly reads 0x6000 here, and
     * its fsck then SKIPS the check unless -f is given.  That is 27 patches past
     * this tree, which sits at about 429 (see vendor/2.11BSD/README for the
     * vintage gap and the patch archive).
     *
     * NOTHING REQUIRES US TO SET IT.  ufs_mount reads the flag and carries it
     * forward -- "if (fs->fs_flags & MNT_CLEAN) flags |= MNT_WASCLEAN;" -- and a
     * zero simply does not take that arm.  Measured rather than reasoned: the
     * live PDP-11/70 mounted disk/fgxufs.dsk and listed its root with this field
     * zero (2026-09-06).  apple/fgx#277.
     */
    unsigned short  sb_flags;
    char            sb_ronly;       /* on-disk read-only flag */
    char            sb_fmod;        /* superblock modified */
    char            sb_flock;       /* held across free-list manipulation */
    char            sb_ilock;       /* held across i-list manipulation */
};

#endif /* _FGX_UFS_FS_H_ */

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/dir.h
 *   Ported from usr/sys/h/dir.h, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* dir.h -- the on-disk directory.  UFS 1.11c.
 *
 * THIS IS THE FORMAT CONTRACT, and it is 2.11BSD's rather than Reno's.  The
 * two differ in the one field that matters here: Reno's `struct direct` opens
 * with `u_long d_ino` (ufs/dir.h:56), 2.11BSD's with `ino_t d_ino`, and its
 * own header explains the change -- "inode numbers are ino_t rather than
 * u_long now.  before, when v7direct was used for the kernel, inode numbers
 * were u_short/ino_t anyways".  So the header is SIX bytes here and eight
 * there, and a port that took Reno's layout would read every name two bytes
 * late.
 *
 * MEASURED, NOT ASSUMED.  The first version of the probe's directory case was
 * written against 2.11BSD's OLDER fixed 16-byte `direct` -- a 2-byte inode
 * number followed by a 14-byte name -- and failed on the third byte.  The root
 * directory of disk/ufsscratch.fs actually begins:
 *
 *     02 00  08 00  01 00  2e 00           d_ino=2 reclen=8 namlen=1 "."
 *     02 00  0c 00  02 00  2e 2e 00 00     d_ino=2 reclen=12 namlen=2 ".."
 *     00 00
 *     03 00  14 00  0a 00  6c 6f 73 74 ... d_ino=3 reclen=20 namlen=10 "lost+f..."
 *
 * which is the variable-length layout below, and agrees with `fgxfs`.
 *
 *----------------------------------------------------------------------------
 * NO CODEC, AND THAT IS WHY THIS IS A HEADER AND NOT A ufs_dirdecode().
 *
 * Every field is 16 bits, and a short overlays this machine directly -- the
 * same reason ufs_dget16 is "a read rather than a conversion".  The superblock
 * and the inode need codecs because they carry 32-bit fields whose halves the
 * PDP-11 stores swapped; a directory entry has none.  So an entry is read in
 * place out of the buffer, which is also what upstream does.
 *
 *----------------------------------------------------------------------------
 * THREE SIZES, AND CONFUSING THEM CORRUPTS VOLUMES.  tools/fgxfs.py's header
 * says it first and it is worth repeating where the kernel reads them:
 *
 *   the FILESYSTEM block is 1024 bytes (FS_BLKSIZE) -- what every daddr_t counts
 *   the DEVICE sector is 512 bytes -- what the block layer transfers
 *   DIRBLKSIZ is 512 and is NEITHER of the others
 *
 * A directory's 1024-byte filesystem block therefore holds TWO independent
 * 512-byte directory blocks, and AN ENTRY MAY NOT STRADDLE THEM.  That is the
 * invariant a scan relies on to resynchronise: every DIRBLKSIZ boundary starts
 * a fresh entry, so a corrupt d_reclen can lose at most one 512-byte block's
 * worth of entries rather than the rest of the directory.
 */
#ifndef _UFS_DIR_H_
#define _UFS_DIR_H_

#include "fsparam.h"

#define DIRBLKSIZ       512
#define MAXNAMLEN       63

/* struct direct -- 2.11BSD usr/sys/h/dir.h:25-30.
 *
 * d_name IS DECLARED AT ITS MAXIMUM and no entry on disk is that long: the
 * record is d_reclen bytes, of which the name occupies d_namlen plus at least
 * one NUL, padded out to a 4-byte multiple.  Reading `sizeof(struct direct)`
 * bytes off a disk buffer would run past the entry and, at the end of a
 * directory block, past the buffer -- which is what DIRSIZ exists to prevent
 * and why nothing here ever copies a whole struct.
 *
 * Upstream's own comment on `struct dirtemplate` says the same from the other
 * side: "Should use struct direct's, but the name field is MAXNAMLEN - 1, and
 * this just won't do."
 */
struct direct {
    ino_t           d_ino;                  /* 0 means a FREE entry */
    unsigned short  d_reclen;               /* bytes to the next entry */
    unsigned short  d_namlen;               /* bytes of name, without the NUL */
    char            d_name[MAXNAMLEN + 1];
};

/* The header, without the name.  Six bytes, and it is spelled as a constant
 * rather than `sizeof(struct direct) - (MAXNAMLEN+1)` because fcc's sizeof on
 * a struct whose last member is an array is exactly the kind of thing this
 * campaign has been bitten by, and because 6 is a FORMAT number: it is what a
 * PDP-11 wrote, not what this compiler computes. */
#define DIRHDRSIZ       6

/* DIRSIZ -- how much space an entry with this name length actually occupies.
 * 2.11BSD's macro, with the sizeof arithmetic replaced by DIRHDRSIZ:
 *
 *   #define DIRSIZ(dp) \
 *     ((((sizeof (struct direct) - (MAXNAMLEN+1)) + (dp)->d_namlen+1) + 3) &~ 3)
 *
 * The +1 is the NUL ("All names are guaranteed null terminated") and the &~3
 * is the 4-byte padding.  An entry whose d_reclen EXCEEDS this is carrying
 * free space after it -- that is how upstream represents a deleted name, and
 * why a scan must step by d_reclen and never by DIRSIZ. */
#define DIRSIZ(namlen)  ((DIRHDRSIZ + (namlen) + 1 + 3) & ~3)

#endif /* _UFS_DIR_H_ */

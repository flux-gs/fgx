/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/fs.h
 *   The constant definitions below are from usr/sys/h/fs.h and
 *   usr/sys/pdp/machparam.h, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* ufsdisk.h -- what <sys/fs.h>, <sys/inode.h> and <sys/dir.h> mean here.
 * UFS 2.1, for src/userland/fsck.
 *
 * On 2.11BSD those three headers ARE the kernel's -- /usr/include/sys is the
 * same tree /usr/src/sys/h is -- so fsck and the kernel cannot disagree about
 * the on-disk format.  FGX keeps its UFS headers under src/kernel/vfs, so this
 * file is how a userland program says the same thing: it includes THOSE
 * headers, and adds upstream's spellings for the handful of constants FGX
 * named differently.  The build passes -I src/kernel/vfs.
 *
 * THE ONE HEADER NOT REACHED THIS WAY IS <sys/dir.h>, AND IT IS A TRAP RATHER
 * THAN AN OMISSION.  toolchain/include/sys/dir.h exists, is on the default
 * include path, and describes a COMPLETELY DIFFERENT `struct direct': it is
 * the LIBC userland dirent, which readdir(3) fills from a SYS_LISTDIR
 * snapshot: no d_reclen, and DIRSIZ(dp) defined as sizeof(struct direct).
 * (Its MAXNAMLEN agrees at 63 since apple/fgx#317; the struct still does not.)  A UFS tool that
 * picked that one up would compile and then read every directory wrong.  So
 * fsck includes src/kernel/vfs/dir.h explicitly and never <sys/dir.h>.
 */

#ifndef _FSCK_UFSDISK_H_
#define _FSCK_UFSDISK_H_

#include <sys/types.h>  /* u_long and friends; sets the _FGX_HAVE_* guards   */

#include "ufs_fs.h"     /* struct ufs_sb, SB_*, INOPB, NICFREE, itod, itoo  */
#include "inode.h"      /* struct dinode and the di_* field aliases         */
#include "dir.h"        /* struct direct, DIRBLKSIZ, DIRSIZ -- 2.11BSD's    */

/* DIRSIZ TAKES A LENGTH HERE, NOT A POINTER.  Upstream's macro is
 * DIRSIZ(dp) over a `struct direct *'; src/kernel/vfs/dir.h takes the name
 * length instead, because its sizeof arithmetic became the constant DIRHDRSIZ
 * (6 is a FORMAT number -- what a PDP-11 wrote -- not what this compiler
 * computes).  The six call sites in dir.c and pass2.c pass `X->d_namlen' or
 * `X.d_namlen' accordingly.  Spelled out here because the mismatch is SILENT
 * in the other direction: a pointer where a length belongs still compiles as
 * arithmetic and yields a plausible-looking size. */

/* DEV_BSIZE is 1024 and so is FS_BLKSIZE; the two names are the same number
 * and NOT the same idea.  usr/sys/pdp/machparam.h:57-58 calls the filesystem
 * block DEV_BSIZE because on a PDP-11 the device block IS 1024.  FGX's device
 * sector is 512, and ufs_fs.h renamed the constant for exactly that reason --
 * "the name differs because FGX's DEVICE sector is 512 and calling both
 * DEV_BSIZE is how the two get confused."
 *
 * fsck keeps upstream's spelling rather than being rewritten to FS_BLKSIZE, so
 * that its 30-odd uses still read against the 2.11BSD source they came from.
 * The VALUE comes from fsparam.h either way, so there is still one definition
 * in the tree and this is an alias, not a second opinion. */
#define DEV_BSIZE       FS_BLKSIZE
#define DEV_BSHIFT      FS_BSHIFT
#define DEV_BMASK       FS_BMASK
#define MAXBSIZE        FS_BLKSIZE      /* usr/sys/h/param.h:85 */

/* usr/sys/h/fs.h:23-28.  SBLOCK is BBLOCK + BBSIZE/DEV_BSIZE = 0 + 1 there,
 * which is SUPERB; ufs_fs.h already carries the number as UFS_SBLOCK. */
#define SBSIZE          DEV_BSIZE
#define SBLOCK          ((daddr_t)UFS_SBLOCK)
#define SUPERB          ((daddr_t)UFS_SBLOCK)
#define ROOTINO         ((ino_t)UFS_ROOTINO)

/* usr/sys/h/fs.h:95-98, verbatim.  Shifts rather than divides, and ufs_fs.h's
 * note on NINDIR gives the reason in full: fcc has no divide instruction. */
#define blkoff(loc)     ((loc) & DEV_BMASK)
#define lblkno(loc)     ((loc) >> DEV_BSHIFT)

/* From usr/sys/h/param.h.  fsck does NOT include <sys/param.h>: that header
 * includes <sys/dir.h>, which on FGX is the ProDOS userland dirent described
 * above, and its `struct direct' collides with the real one.  So the three
 * things fsck wanted from it are here.
 *
 * MAXPATHLEN IS UPSTREAM'S 256, NOT FGX'S 128, and the difference is the
 * filesystem rather than the platform.  toolchain/include/sys/param.h says
 * "ProDOS paths are short" and sizes cwd buffers by it; this tool walks a
 * 2.11BSD tree whose names run to MAXNAMLEN 63, and pathname[] is what
 * getpathname reconstructs a descent into.  usr/sys/h/param.h:98 says 256, so
 * a volume this fsck can name is a volume the machine that wrote it can name.
 * Nothing in libc takes a MAXPATHLEN-sized buffer from fsck, so the larger
 * value stays inside the program. */
#undef  MAXPATHLEN
#define MAXPATHLEN      256
#ifndef howmany
#define howmany(x, y)   (((x) + ((y) - 1)) / (y))
#endif
#ifndef roundup
#define roundup(x, y)   ((((x) + ((y) - 1)) / (y)) * (y))
#endif

/* struct dirtemplate -- usr/sys/h/dir.h, verbatim.  The prototype "." and ".."
 * pair fsck writes when it builds or repairs a directory (dir.c's `emptydir'
 * and `dirhead', pass2's `proto').
 *
 * src/kernel/vfs/dir.h does not carry it and should not: PROVENANCE records
 * that the header keeps 2.11BSD's ON-DISK half and leaves the `_dirdesc'/`DIR'
 * half to userland, and this template is the same kind of thing -- a userland
 * convenience laid out to match the format, not part of the format.  The
 * comments on the two name fields are upstream's and are load-bearing: the
 * sizes are what make each entry's length a multiple of four, which is the
 * alignment d_reclen must satisfy. */
struct dirtemplate {
	ino_t		dot_ino;
	unsigned short	dot_reclen;
	unsigned short	dot_namlen;
	char		dot_name[2];		/* must be multiple of 4 */
	ino_t		dotdot_ino;
	unsigned short	dotdot_reclen;
	unsigned short	dotdot_namlen;
	char		dotdot_name[6];		/* ditto */
};

#endif /* _FSCK_UFSDISK_H_ */

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/include/fstab.h
 *   Ported from usr/include/fstab.h, 2.11BSD (@(#)fstab.h 8.1.1 1996/1/15).
 *   Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 */
/* fstab.h -- the file system table, see fstab(5).  UFS 2.1.
 *
 * THE 8.1.1 VINTAGE, NOT THE 5.1 ONE, and the difference is load-bearing.
 * examples/2.11BSD ships a 1985 fstab.h with no fs_vfstype beside a 1993
 * fstab.c that sets it; vendor/2.11BSD/usr/sbin/fsck/main.c (5.4.1, 1996)
 * reads fsp->fs_vfstype directly, so only the later header can build it.  The
 * live oracle settled which is real -- see vendor/2.11BSD/usr/include/
 * README.fstab.
 *
 * FSTAB is upstream's older spelling of _PATH_FSTAB and both are kept: fsck
 * uses FSTAB, newer 2.11BSD sources use _PATH_FSTAB.
 */
#ifndef _FSTAB_H_
#define _FSTAB_H_

#define _PATH_FSTAB     "/etc/fstab"
#define FSTAB           "/etc/fstab"

#define FSTAB_RW        "rw"    /* read/write device */
#define FSTAB_RQ        "rq"    /* read/write with quotas */
#define FSTAB_RO        "ro"    /* read-only device */
#define FSTAB_SW        "sw"    /* swap device */
#define FSTAB_XX        "xx"    /* ignore totally */

struct fstab {
        char    *fs_spec;       /* block special device name */
        char    *fs_file;       /* file system path prefix */
        char    *fs_vfstype;    /* File system type, ufs, nfs */
        char    *fs_mntops;     /* Mount options ala -o */
        char    *fs_type;       /* FSTAB_* from fs_mntops */
        int     fs_freq;        /* dump frequency, in days */
        int     fs_passno;      /* pass number on parallel dump */
};

struct fstab *getfsent();
struct fstab *getfsspec();
struct fstab *getfsfile();
int  setfsent();
void endfsent();

#endif /* !_FSTAB_H_ */

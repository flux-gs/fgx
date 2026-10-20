/* FGX libc — sys/param.h.  BSD system limits + counting macros for ports.
 *
 * Machine-independent BSD <sys/param.h> shapes, with values sized to FGX:
 * 16-bit int, ProDOS short paths, and the libc exec-staging arena.  Standard
 * limits that other headers already own are pulled in (one source of truth):
 * MAXNAMLEN from <sys/dir.h>, BUFSIZ from <stdio.h>.
 */
#ifndef _SYS_PARAM_H
#define _SYS_PARAM_H

#include <sys/types.h>
#include <stdio.h>              /* BUFSIZ = 1024 */
#include <sys/dir.h>           /* MAXNAMLEN = 63 (2.11BSD usr/sys/h/dir.h:13) */
#include <signal.h>            /* as 2.11BSD usr/sys/h/param.h:54 does: NSIG,
                                 * and the SIG* names a program may use */

#ifndef NULL
#define NULL ((char *)0)
#endif

#define BSD     198            /* generic "4.xBSD" marker for #if BSD >= ... */

#ifndef MAXPATHLEN
#define MAXPATHLEN  128         /* 2.11BSD's is 256; sizes cwd and namei buffers,
                                   and the kernel's path staging agrees (the
                                   syscall buffers are SYS_PATHBUF_MAX) */
#endif
#ifndef NOFILE
#define NOFILE      30          /* max open files per process: the kernel's
                                   FS_MAX_FDS (include/fs.s), 2.11BSD's 30 */
#endif
#ifndef NCARGS
#define NCARGS      768         /* = the libc exec-staging arena (E2BIG gate) */
#endif
#ifndef MAXHOSTNAMELEN
#define MAXHOSTNAMELEN 64
#endif
#ifndef NGROUPS
#define NGROUPS     1           /* single-user FGX: group 0 only */
#endif

/* The largest filesystem block, 2.11BSD's (usr/sys/h/param.h): a UFS
 * block here is 1024 bytes too. */
#ifndef MAXBSIZE
#define MAXBSIZE    1024
#endif

/* Fast min/max. */
#ifndef MIN
#define MIN(a, b)   (((a) < (b)) ? (a) : (b))
#endif
#ifndef MAX
#define MAX(a, b)   (((a) > (b)) ? (a) : (b))
#endif

/* Counting and rounding. */
#ifndef howmany
#define howmany(x, y)   (((x) + ((y) - 1)) / (y))
#endif
#ifndef roundup
#define roundup(x, y)   ((((x) + ((y) - 1)) / (y)) * (y))
#endif

/* Device blocks <-> bytes, verbatim from 2.11BSD's pdp/machparam.h:111-114.
 * DEV_BSIZE is 512 and DEV_BSHIFT 9, as it is on the volume this system reads.
 * ls(1) needs dbtob to turn st_blocks into the `total' line and the -s column;
 * both are `long' casts upstream because a block count times 512 leaves a
 * 16-bit int at 128 blocks, which is 64 KB -- a size this filesystem passes
 * without noticing. */
#ifndef DEV_BSHIFT
#define DEV_BSHIFT      9
#endif
#ifndef DEV_BSIZE
#define DEV_BSIZE       (1 << DEV_BSHIFT)
#endif
#define btodb(bytes)    ((long)(bytes) >> DEV_BSHIFT)
#define dbtob(db)       ((long)(db) << DEV_BSHIFT)

#endif /* _SYS_PARAM_H */

/* setlogin(2)/getlogin(2)'s login name.  2.11BSD h/param.h:132; the kernel's
 * U_LOGIN_LEN (include/kernel.s) is the same number and is the authority --
 * this is the copy userland compiles against, as with the errnos. */
#define MAXLOGNAME      16

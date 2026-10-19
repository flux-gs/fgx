/* sys/param.h -- FGX port shim for the tcsh 6.00 direct port.
 * Provides the system limits tcsh expects; values fit FGX (ProDOS FS,
 * 768-byte exec-staging arena, 16-bit int).  Standard constants pull from
 * the real FGX libc headers so there is one source of truth. */
#ifndef _FGX_SYS_PARAM_H
#define _FGX_SYS_PARAM_H

#include <sys/types.h>
#include <stdio.h>              /* BUFSIZ = 1024 */
#include <sys/dir.h>           /* MAXNAMLEN = 63 (2.11BSD usr/sys/h/dir.h:13) */

#ifndef MAXPATHLEN
#define MAXPATHLEN  128         /* ProDOS paths are short; tcsh cwd buffers */
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

/* Common BSD param.h helper macros tcsh may use. */
#ifndef howmany
#define howmany(x, y)   (((x) + ((y) - 1)) / (y))
#endif
#ifndef roundup
#define roundup(x, y)   ((((x) + ((y) - 1)) / (y)) * (y))
#endif

#endif /* _FGX_SYS_PARAM_H */

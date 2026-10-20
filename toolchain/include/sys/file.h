/* FGX libc — sys/file.h.  BSD file-descriptor + seek + flock names for ports.
 *
 * The real open(2)/lseek(2) flags live in <fcntl.h> (included below); this adds
 * the BSD spellings BSD sources use: the L_* lseek whences, the F* open modes,
 * the FD_CLOEXEC descriptor flag, and the flock(2) constants.
 */
#ifndef _SYS_FILE_H
#define _SYS_FILE_H

#include <fcntl.h>

/* lseek(2) whences, BSD spelling (== SEEK_SET/CUR/END). */
#ifndef L_SET
#define L_SET   0              /* absolute */
#define L_INCR  1              /* relative to current */
#define L_XTND  2              /* relative to EOF */
#endif

/* BSD kernel file-flag spellings (fp->f_flag). */
#ifndef FREAD
#define FREAD   0x0001
#define FWRITE  0x0002
#endif

/* fcntl(2) F_GETFD/F_SETFD close-on-exec flag. */
#ifndef FD_CLOEXEC
#define FD_CLOEXEC 1
#endif

/* flock(2) operations, SYS_FLOCK (128).  Reno sys/fcntl.h:49-52. */
#define LOCK_SH 1              /* shared lock */
#define LOCK_EX 2              /* exclusive lock */
#define LOCK_NB 4              /* don't block when locking */
#define LOCK_UN 8              /* unlock */

int flock(int fd, int how);

#endif /* _SYS_FILE_H */

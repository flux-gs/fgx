/* FGX libc — fcntl.h.  open(2) flags + prototype.
 *
 * Flag VALUES mirror the kernel's include/fs.s "Open flags (2.11BSD layout)"
 * (the authoritative source; consumed by SYS_OPEN #5).  Keep in sync.
 * open()/creat() carry real prototypes (matching the libc pile) so a
 * null-pointer-constant arg would widen correctly under the B2 uniform-R-to-L
 * ABI.  SYS_OPEN ignores any mode argument (ProDOS has no permission bits),
 * but the POSIX 3-arg open(path,flags,mode) form must still COMPILE: ports
 * write it unconditionally alongside O_CREAT (novi's buffer.c does).  The
 * trailing `...` is declaration-only -- R-to-L pushes put the extra mode
 * DEEPER than the two words the implementation reads, and the caller cleans
 * up, so 2-arg call sites emit exactly as before (see syscall_file.c:28).
 */
#ifndef _FCNTL_H
#define _FCNTL_H

#define O_RDONLY        0x0000
#define O_WRONLY        0x0001
#define O_RDWR          0x0002
#define O_NONBLOCK      0x0004          /* FNDELAY: reads and writes don't wait */
#define O_NDELAY        O_NONBLOCK
#define O_APPEND        0x0008          /* writes seek-to-EOF first */
#define O_CREAT         0x0200
#define O_TRUNC         0x0400
#define O_EXCL          0x0800

/* fcntl(2), SYS_FCNTL (127).  4.3BSD-Reno sys/fcntl.h:26-40.  F_GETOWN and
 * F_SETOWN answer EINVAL: FGX sends no SIGIO or SIGURG for them to name a
 * receiver of. */
#define F_DUPFD         0               /* duplicate file descriptor */
#define F_GETFD         1               /* get file descriptor flags */
#define F_SETFD         2               /* set file descriptor flags */
#define F_GETFL         3               /* get file status flags */
#define F_SETFL         4               /* set file status flags */
#define F_GETOWN        5               /* get SIGIO/SIGURG proc/pgrp */
#define F_SETOWN        6               /* set SIGIO/SIGURG proc/pgrp */
#define FD_CLOEXEC      1               /* close-on-exec flag */

int open(char *path, int flags, ...);
int creat(char *path, int mode);
int fcntl(int fd, int cmd, ...);

/* F_GETFL/F_SETFL's flags under their 2.11BSD names (usr/include/fcntl.h,
 * "copied from <sys/file.h>"), the same bits as the O_ names above.  FASYNC is
 * left out: O_ASYNC is not accepted (fcntl(2) BUGS). */
#define FNDELAY         O_NONBLOCK      /* non-blocking reads */
#define FAPPEND         O_APPEND        /* append on each write */
#define FCREAT          O_CREAT         /* create if nonexistant */
#define FTRUNC          O_TRUNC         /* truncate to zero length */
#define FEXCL           O_EXCL          /* error if already created */

#endif /* _FCNTL_H */

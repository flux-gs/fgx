/* FGX libc — errno.h.  Error codes for C programs.
 *
 * Values MIRROR the kernel's authoritative include/errno.s (keep in sync).
 * FGX syscall wrappers return the code in A on the failure path (C=0); the
 * C-callable libc wrappers surface failure as a negative/-1 return.  A global
 * `errno` cell is declared here for BSD-style ports (e.g. elvis) that test it;
 * libc defines the cell and the syscall wrappers set it on failure.
 */
#ifndef _ERRNO_H
#define _ERRNO_H

extern int errno;

#define ENOENT          2       /* no such file or directory */
/* Values FGX does not itself return yet, provided so BSD port source
 * compares against them as written (tcsh tests errno == EACCES).
 * Canonical 4.3BSD/2.11BSD numbers, mirroring include/errno.s. */
#define EPERM           1       /* not owner / operation not permitted */
#define EACCES          13      /* permission denied */
#define EFAULT          14      /* bad address */
#define ENOTBLK         15      /* block device required */
#define ENODEV          19      /* no such device */
#define ETXTBSY         26      /* text file busy */
#define EMLINK          31      /* too many links */
#define EDOM            33      /* argument out of domain */
#define ERANGE          34      /* result too large */
#define ESRCH           3       /* no such process */
#define EINTR           4       /* interrupted by a signal (^C) */
#define EIO             5       /* I/O error */
#define ENXIO           6       /* no such device or address */
#define E2BIG           7       /* argument list too long (exec/spawn staging) */
#define ENOEXEC         8       /* binary not in valid format */
#define EBADF           9       /* bad file descriptor */
#define ECHILD          10      /* no child processes */
#define EAGAIN          11      /* resource temporarily unavailable */
#define EWOULDBLOCK     EAGAIN  /* op would block (BSD alias; net stack -> EAGAIN) */
#define ENOMEM          12      /* out of memory */
#define EBUSY           16      /* device or resource busy */
#define EEXIST          17      /* file exists */
#define EXDEV           18      /* cross-device link (mv: rename→copy fallback) */
#define ENOTDIR         20      /* not a directory */
#define EISDIR          21      /* is a directory */
#define EINVAL          22      /* invalid argument */
#define ENFILE          23      /* file table overflow */
#define EMFILE          24      /* too many open files */
#define ENOTTY          25      /* inappropriate ioctl for device */
#define EFBIG           27      /* file too large (16 MB tree limit) */
#define ENOSPC          28      /* no space left on device */
#define ESPIPE          29      /* illegal seek (pipe/console/dir) */
#define EROFS           30      /* read-only file system */
#define EPIPE           32      /* broken pipe */
#define ENOPROTOOPT     42      /* protocol option not available */
#define ENOTSUP         45      /* operation not supported */
#define EOPNOTSUPP      ENOTSUP /* BSD spelling on a socket (same number) */
#define ELOOP           62      /* too many levels of symbolic links */
#define ENOTEMPTY       66      /* directory not empty (rmdir) */
#define EADDRNOTAVAIL   49      /* can't assign requested address */
#define ECONNRESET      54      /* connection reset by peer */
#define EISCONN         56      /* socket is already connected */
#define ENOTCONN        57      /* socket is not connected */
#define ETIMEDOUT       60      /* connection timed out */
#define ECONNREFUSED    61      /* connection refused */
#define ENOBUFS         55      /* no buffer space available (send queue full) */
#define ENOTSOCK        38      /* socket operation on non-socket */
#define EPROTOTYPE      41      /* protocol wrong type for socket */
#define EADDRINUSE      48      /* address already in use */
#define EAFNOSUPPORT    47      /* address family not supported */
#define EDESTADDRREQ    39      /* destination address required */
#define EMSGSIZE        40      /* message too long for the buffer */
#define ENAMETOOLONG    63      /* file name too long */
#define ENOSYS          78      /* function not implemented */

#endif /* _ERRNO_H */

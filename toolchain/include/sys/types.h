/* FGX libc — sys/types.h.  Primitive system typedefs (2.11BSD-shaped).
 *
 * Sized for the fcc/65816 model: int = 16-bit, long = 32-bit.  off_t/time_t
 * are 32-bit (ProDOS EOF is 24-bit; time_t is the Unix epoch synthesized by
 * the kernel).  size_t matches libc (unsigned long, train-2 M-4); fcc
 * permits the duplicate typedef.
 */
#ifndef _SYS_TYPES_H
#define _SYS_TYPES_H

#ifndef NULL
#define NULL ((char *)0)                          /* 2.11BSD sys/types.h defines NULL */
#endif

/* The _FGX_HAVE_* guards let src/kernel/vfs/fsparam.h and this header appear
 * in either order in one translation unit.  That header declares the same
 * scalars for the kernel's banks and guards them the same way; the pair became
 * load-bearing at UFS 2.1, when src/userland/fsck -- a USERLAND program that
 * needs the on-disk format -- began including both.  Defining a macro here
 * changes nothing for any other program. */
#define _FGX_HAVE_INO_T
#define _FGX_HAVE_UID_T
#define _FGX_HAVE_GID_T
#define _FGX_HAVE_DEV_T
#define _FGX_HAVE_OFF_T

typedef unsigned long   size_t;         /* 32-bit (M-4; was int) */
typedef long            ssize_t;        /* signed size_t: read/write return */
typedef long            off_t;          /* file offset (SYS_LSEEK is 32-bit) */
/* time_t: guarded so <time.h> (ANSI home of time_t) and this header can be
 * included in either order under fcc's no-nested-include convention. */
#ifndef _FGX_HAVE_TIME_T
#define _FGX_HAVE_TIME_T
typedef long            time_t;         /* Unix epoch seconds */
#endif
typedef int             pid_t;
typedef unsigned short  mode_t;
typedef unsigned short  uid_t;
typedef unsigned short  gid_t;
typedef short           dev_t;

/* major()/minor(), verbatim from 2.11BSD's h/types.h:17-20.  A dev_t is one
 * byte of each, which is the split `fgxfs mknod' already writes and the kernel
 * already reports: /dev/console is `c 7' (major 0, minor 7) and /dev/sd0 is
 * `b 258' (major 1, minor 2).  ls -l needs them to print the two columns it
 * shows in place of a size for a device. */
#define major(x)        ((int)(((int)(x) >> 8) & 0377))
#define minor(x)        ((int)((x) & 0377))
typedef unsigned short  ino_t;
typedef unsigned short  nlink_t;

typedef unsigned char   u_char;
typedef unsigned short  u_short;
typedef unsigned int    u_int;
typedef unsigned long   u_long;
typedef char *          caddr_t;

/* select(2) fd_set (2.11BSD-shaped, sized to FGX's small per-task fd table —
 * one 32-bit word covers fds 0..31). */
#ifndef FD_SETSIZE
#define FD_SETSIZE 32
typedef struct fd_set { long fds_bits[1]; } fd_set;
#define FD_SET(n,p)   ((p)->fds_bits[0] |=  (1L << (n)))
#define FD_CLR(n,p)   ((p)->fds_bits[0] &= ~(1L << (n)))
#define FD_ISSET(n,p) ((p)->fds_bits[0] &   (1L << (n)))
#define FD_ZERO(p)    ((p)->fds_bits[0] = 0)
#endif

#endif /* _SYS_TYPES_H */

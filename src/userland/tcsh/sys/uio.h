/* sys/uio.h -- FGX port shim for tcsh.  struct iovec for scatter/gather;
 * FGX read/write are scalar, so tcsh's writev path (if used) reduces to write. */
#ifndef _FGX_SYS_UIO_H
#define _FGX_SYS_UIO_H
#include <sys/types.h>
struct iovec { char *iov_base; int iov_len; };
extern int writev(), readv();
#endif /* _FGX_SYS_UIO_H */

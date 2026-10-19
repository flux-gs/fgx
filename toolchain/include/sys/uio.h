/* FGX libc -- sys/uio.h.  BSD scatter/gather iovec + readv/writev.
 *
 * readv/writev are syscalls (122/123): one uio, one transfer, as 2.11BSD's.
 */
#ifndef _SYS_UIO_H
#define _SYS_UIO_H

#include <sys/types.h>          /* caddr_t */

struct iovec {
    caddr_t iov_base;          /* base address of the buffer */
    int     iov_len;           /* length of the buffer */
};

int readv(int fd, struct iovec *iov, int iovcnt);
int writev(int fd, struct iovec *iov, int iovcnt);

#endif /* _SYS_UIO_H */

/* readv(2)/writev(2) -- SYS_READV (122) and SYS_WRITEV (123).
 *
 * The kernel does what 2.11BSD's readv()/writev() and rwuio() do
 * (vendor/2.11BSD/usr/sys/sys/sys_generic.c:57-171): copy the vector in,
 * refuse more than 16 entries with EINVAL, sum the lengths, and hand ONE uio to
 * the descriptor's fo_rw.  So a vector reaches a pipe, a socket or a terminal
 * as one transfer, and no other writer lands between its entries.
 *
 * The iovec array rides as read(2)'s buffer does: its offset in X and its bank
 * through __syscall_db.  Each iov_base is a full fcc pointer and carries its own
 * bank.
 *
 * DIVERGENCE: a total past 32767 is EINVAL, where upstream's limit is the wider
 * uio_resid -- the count comes back in one 16-bit word shared with the errno,
 * the limit read(2) has too.
 */

int writev(int fd, struct iovec *iov, int iovcnt)
{
    unsigned long lp = (unsigned long)iov;
    int r = (int)__syscall_db(123, (unsigned)(lp >> 16), fd, (unsigned)lp,
                              iovcnt);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

int readv(int fd, struct iovec *iov, int iovcnt)
{
    unsigned long lp = (unsigned long)iov;
    int r = (int)__syscall_db(122, (unsigned)(lp >> 16), fd, (unsigned)lp,
                              iovcnt);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

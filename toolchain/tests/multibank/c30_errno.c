/* c30_errno.c — errno round-trip (2026-07-06 quick-win): a failing syscall
 * must land the kernel's errno in the libc_data cell.  Before this batch
 * errno.h's promise was FALSE — the kernel computed codes and the shims
 * discarded them at the -1 flattening point (2026-07-05 audit). */
extern int open(char *path, int flags);
extern int errno;

int c30_check(void)
{
	int fd;
	errno = 0;
	fd = open("/no/such/dir/c30x", 0);
	if (fd != -1) return 0;
	return errno == 2;               /* ENOENT (include/errno.h) */
}

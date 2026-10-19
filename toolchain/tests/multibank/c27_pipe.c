/* c27_pipe.c — SHIM-population construct (2026-07-05 audit): pipe(2) into a
 * SOFT-STACK local fd array.  c_pipe used to pass only the 16-bit offset, so
 * the kernel (bank = _Sys_CallerBank = caller DBR) wrote fd[0..1] into the
 * DATA bank at the local's offset and the local stayed untouched.  The fixed
 * shim swaps DBR to the caller-pushed pointer bank (SYSCALL_PTRARG).  The
 * write/read round-trip also exercises c_write/c_read on soft-stack buffers. */
extern int pipe(int *fd);
extern int write(int fd, char *buf, int n);
extern int read(int fd, char *buf, int n);
extern int close(int fd);

int c27_check(void)
{
	int fd[2];
	char wb[4];
	char rb[4];
	int ok;

	fd[0] = -1;
	fd[1] = -1;
	if (pipe(fd) != 0) return 0;
	if (fd[0] < 0 || fd[1] < 0) return 0;   /* kernel wrote the wrong bank */
	wb[0] = 'Q'; wb[1] = '7'; wb[2] = 'z'; wb[3] = 0;
	if (write(fd[1], wb, 4) != 4) { close(fd[0]); close(fd[1]); return 0; }
	rb[0] = 0; rb[1] = 0; rb[2] = 0; rb[3] = 0;
	if (read(fd[0], rb, 4) != 4) { close(fd[0]); close(fd[1]); return 0; }
	ok = (rb[0] == 'Q' && rb[1] == '7' && rb[2] == 'z' && rb[3] == 0);
	close(fd[0]);
	close(fd[1]);
	return ok;
}

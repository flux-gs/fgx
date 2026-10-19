/* c31_getcwd.c — getwd(3) into a SOFT-STACK local buffer (SYSCALL_PTRARG
 * class, 2026-07-06): the kernel writes the cwd through the pushed buffer
 * bank; the return is the fcc pointer convention (buf offset + bank).  Only
 * shape is asserted (leading '/').
 *
 * getwd, not getcwd: libc provides only the BSD spelling, so vendored BSD
 * sources compile as written.  It takes no size and requires MAXPATHLEN. */
extern char *getwd(char *buf);

int c31_check(void)
{
	char buf[128];              /* MAXPATHLEN: getwd has no size arg */
	char *p;

	buf[0] = 0;
	p = getwd(buf);
	if (p == 0) return 0;
	return buf[0] == '/';
}

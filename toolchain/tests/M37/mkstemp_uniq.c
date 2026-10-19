/* mkstemp_uniq: mkstemp(3) over SYS_OPEN's O_EXCL.  FGX-only (MAME oracle):
 * creates real files under /tmp on the boot disk.
 *
 * THE THIRD CHECK IS THE POINT.  _gettemp seeds the trailing X's from the pid,
 * so two mkstemp calls on the same template START from the same candidate
 * name.  The first claims it; the second must collide, get EEXIST, and walk
 * the name forward -- and it only collides because O_CREAT|O_EXCL FAILS on an
 * existing file.  FGX's SYS_OPEN used to ignore O_EXCL and fall back to a
 * plain open, which handed the second caller the FIRST caller's file: same
 * name, same bytes, no error.  Drop the O_EXCL arm from _Sys_Open and this
 * check goes red while the other two stay green.
 *
 * 12 + 10 + 20 = 42. */
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>

int
sameis(char *a, char *b)
{
	int i = 0;

	while (a[i] && a[i] == b[i]) i++;
	return a[i] == b[i];
}

int
hasx(char *s)
{
	while (*s) {
		if (*s == 'X') return 1;
		s++;
	}
	return 0;
}

int
main()
{
	char t0[24], t1[24];
	char buf[8];
	int fd0, fd1, r = 0;

	strcpy(t0, "/tmp/fgtXXXXXX");
	strcpy(t1, "/tmp/fgtXXXXXX");

	fd0 = mkstemp(t0);
	if (fd0 >= 0 && !hasx(t0)) r += 12;      /* claimed, template rewritten */

	if (fd0 >= 0) {
		if (write(fd0, "novi", 4) == 4 &&
		    lseek(fd0, 0L, 0) == 0L &&
		    read(fd0, buf, 4) == 4 &&
		    buf[0] == 'n' && buf[3] == 'i')
			r += 10;                 /* it is a real, usable file */
	}

	fd1 = mkstemp(t1);
	if (fd1 >= 0 && !sameis(t0, t1)) r += 20;   /* O_EXCL forced a new name */

	if (fd0 >= 0) { close(fd0); unlink(t0); }
	if (fd1 >= 0) { close(fd1); unlink(t1); }

	return r;                                /* 42 */
}

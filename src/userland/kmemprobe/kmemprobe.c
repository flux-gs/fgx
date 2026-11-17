/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 */
/* kmemprobe -- /dev/mem and /dev/kmem (2.11BSD pdp/mem.c mmrw minors 0 and 1),
 * nlist(3) on the stack's name list /netnix, and kern.netdata, the address of
 * the stack's data bank: what route(8)'s flushroutes reads.  Prints KMEM ok,
 * or KMEM FAIL and the step. */
#include <sys/types.h>
#include <sys/file.h>
#include <sys/sysctl.h>
#include <nlist.h>
#include <stdio.h>
#include <errno.h>

extern int errno;
extern long lseek();

struct nlist nl[] = {
	{ "_rthashsize" },
	{ "_rthost" },
	{ "" },
};

static char cell = 0x11;

static int
fail(what, v)
	char *what;
	long v;
{
	printf("KMEM FAIL %s %ld\n", what, v);
	return (1);
}

int
main()
{
	int mib[2], fd, n, pid, st;
	long netdata, a;
	char c;
	size_t len;

	mib[0] = CTL_KERN;
	mib[1] = KERN_NETDATA;
	len = sizeof (netdata);
	if (sysctl(mib, 2, &netdata, &len, (void *)0, 0) < 0)
		return (fail("sysctl", (long)errno));
	if (netdata == 0 || (netdata & 0xffffL) != 0)
		return (fail("netdata", netdata));
	if (nlist("/netnix", nl) != 0)
		return (fail("nlist", 0L));
	if (nl[0].n_value == 0 || nl[1].n_value == 0)
		return (fail("value", (long)nl[0].n_value));
	if ((fd = open("/dev/kmem", O_RDWR)) < 0)
		return (fail("open", (long)errno));
	if (lseek(fd, netdata + nl[0].n_value, L_SET) < 0 ||
	    read(fd, (char *)&n, sizeof (n)) != sizeof (n))
		return (fail("read", (long)errno));
	if (n != 8)				/* RTHASHSIZ, net/route.h */
		return (fail("rthashsize", (long)n));
	if (lseek(fd, 0xe0c000L, L_SET) < 0 || read(fd, &c, 1) >= 0 ||
	    errno != EFAULT)
		return (fail("iowindow", (long)errno));
	close(fd);
	if ((fd = open("/dev/mem", O_RDWR)) < 0)
		return (fail("mem", (long)errno));
	a = (long)&cell & 0xffffffL;
	c = 0x5a;
	if (lseek(fd, a, L_SET) < 0 || write(fd, &c, 1) != 1 || cell != 0x5a)
		return (fail("write", (long)cell));
	c = 0;
	if (lseek(fd, a, L_SET) < 0 || read(fd, &c, 1) != 1 || c != 0x5a)
		return (fail("readback", (long)c));
	close(fd);
	if ((pid = fork()) == 0) {
		(void) setuid(1);		/* daemon: not in group kmem */
		_exit(open("/dev/kmem", O_RDONLY) < 0 && errno == EACCES ? 0 : 3);
	}
	wait(&st);
	if (st != 0)
		return (fail("perm", (long)st));
	printf("KMEM ok\n");
	return (0);
}

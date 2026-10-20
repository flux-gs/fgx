/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 */
/* ifcprobe -- the SIOCGIF* socket ioctls (2.11BSD net/if.c ifioctl, ifconf;
 * netinet/in.c in_control).  The harness machine has no network card, so the
 * one interface it can see is lo0, which 2.11BSD's ifconf lists as it lists
 * the cards.  Prints IFC OK, or a FAIL line per wrong answer. */
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

extern int errno;

static int fails;

static void
fail(what, v)
	char *what;
	long v;
{
	printf("IFC FAIL %s %ld\n", what, v);
	fails++;
}

int
main()
{
	char buf[256];
	struct ifconf ifc;
	struct ifreq ifr, *r;
	struct sockaddr_in *sin;
	int s, n, i, sawlo;

	s = socket(AF_INET, SOCK_DGRAM, 0);
	if (s < 0) { fail("socket", (long)errno); return 1; }

	ifc.ifc_len = sizeof buf;
	ifc.ifc_buf = buf;
	if (ioctl(s, SIOCGIFCONF, (char *)&ifc) < 0)
		fail("conf", (long)errno);
	n = ifc.ifc_len / sizeof (struct ifreq);
	sawlo = 0;
	for (i = 0; i < n; i++) {
		r = &ifc.ifc_req[i];
		sin = (struct sockaddr_in *)&r->ifr_addr;
		printf("IFC if %s family %d\n", r->ifr_name, sin->sin_family);
		if (strcmp(r->ifr_name, "lo0") == 0) {
			sawlo = 1;
			if (sin->sin_family != AF_INET ||
			    sin->sin_addr.s_addr != htonl(0x7f000001L))
				fail("conf-lo0-addr", (long)sin->sin_family);
		}
	}
	if (!sawlo) fail("conf-no-lo0", (long)n);

	/* space must EXCEED a record for it to be filled: upstream's `space >
	 * sizeof (ifr)' */
	ifc.ifc_len = sizeof (struct ifreq);
	if (ioctl(s, SIOCGIFCONF, (char *)&ifc) < 0 || ifc.ifc_len != 0)
		fail("conf-exact", (long)ifc.ifc_len);

	strcpy(ifr.ifr_name, "lo0");
	if (ioctl(s, SIOCGIFFLAGS, (char *)&ifr) < 0)
		fail("flags", (long)errno);
	else if (ifr.ifr_flags != (IFF_UP|IFF_LOOPBACK|IFF_RUNNING))
		fail("flags-val", (long)ifr.ifr_flags);

	strcpy(ifr.ifr_name, "lo0");
	sin = (struct sockaddr_in *)&ifr.ifr_addr;
	if (ioctl(s, SIOCGIFADDR, (char *)&ifr) < 0)
		fail("addr", (long)errno);
	else if (sin->sin_family != AF_INET ||
	    sin->sin_addr.s_addr != htonl(0x7f000001L))
		fail("addr-val", (long)sin->sin_addr.s_addr);

	strcpy(ifr.ifr_name, "lo0");
	if (ioctl(s, SIOCGIFNETMASK, (char *)&ifr) < 0)
		fail("mask", (long)errno);
	else if (sin->sin_addr.s_addr != htonl(0xff000000L))
		fail("mask-val", (long)sin->sin_addr.s_addr);

	strcpy(ifr.ifr_name, "lo0");
	if (ioctl(s, SIOCGIFBRDADDR, (char *)&ifr) >= 0 || errno != EINVAL)
		fail("brd-lo0", (long)errno);

	strcpy(ifr.ifr_name, "nx9");
	if (ioctl(s, SIOCGIFFLAGS, (char *)&ifr) >= 0 || errno != ENXIO)
		fail("enxio", (long)errno);

	if (!fails)
		printf("IFC OK\n");
	return fails;
}

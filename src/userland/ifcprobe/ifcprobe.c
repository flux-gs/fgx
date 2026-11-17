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
#include <net/if_dl.h>
#include <net/route.h>
#include <netinet/in.h>
#include <arpa/inet.h>
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

/* -l: SIOCADDRT and SIOCDELRT reach rtioctl, and SIOCGIFCONF names each
 * interface's link address.  With a host route to 10.9.9.9 through lo0's own
 * address a datagram to it leaves (ip_input then drops it, not being ours);
 * without one ip_output answers ENETUNREACH. */
static int
rtconn()
{
	struct sockaddr_in to;
	int s, r;

	s = socket(AF_INET, SOCK_DGRAM, 0);
	bzero((char *)&to, sizeof to);
	to.sin_family = AF_INET;
	to.sin_port = htons(7);
	to.sin_addr.s_addr = htonl(0x0a090909L);
	r = sendto(s, "x", 1, 0, (struct sockaddr *)&to, sizeof to) == 1 ? 0 : errno;
	close(s);
	return r;
}

static int
rtreq(s, cmd)
	int s, cmd;
{
	struct rtentry rt;
	struct sockaddr_in *sin;

	bzero((char *)&rt, sizeof rt);
	sin = (struct sockaddr_in *)&rt.rt_dst;
	sin->sin_family = AF_INET;
	sin->sin_addr.s_addr = htonl(0x0a090909L);
	sin = (struct sockaddr_in *)&rt.rt_gateway;
	sin->sin_family = AF_INET;
	sin->sin_addr.s_addr = htonl(0x7f000001L);
	rt.rt_flags = RTF_UP | RTF_HOST;
	return ioctl(s, cmd, (char *)&rt) < 0 ? errno : 0;
}

static int
lmode()
{
	char buf[256];
	struct ifconf ifc;
	struct ifreq *r;
	struct sockaddr_dl *sdl;
	int s, n, i, e, link;

	s = socket(AF_INET, SOCK_DGRAM, 0);
	if ((e = rtconn()) != ENETUNREACH) { printf("IFC L FAIL before %d\n", e); return 1; }
	if ((e = rtreq(s, SIOCADDRT)) != 0) { printf("IFC L FAIL addrt %d\n", e); return 1; }
	if ((e = rtconn()) != 0) { printf("IFC L FAIL route %d\n", e); return 1; }
	if ((e = rtreq(s, SIOCDELRT)) != 0) { printf("IFC L FAIL delrt %d\n", e); return 1; }
	if ((e = rtconn()) != ENETUNREACH) { printf("IFC L FAIL after %d\n", e); return 1; }
	ifc.ifc_len = sizeof buf;
	ifc.ifc_buf = buf;
	if (ioctl(s, SIOCGIFCONF, (char *)&ifc) < 0) { printf("IFC L FAIL conf %d\n", errno); return 1; }
	n = ifc.ifc_len / sizeof (struct ifreq);
	link = 0;
	for (i = 0; i < n; i++) {
		r = &ifc.ifc_req[i];
		sdl = (struct sockaddr_dl *)&r->ifr_addr;
		if (sdl->sdl_family != AF_LINK)
			continue;
		printf("IFC link %s type %d alen %d\n", r->ifr_name, sdl->sdl_type, sdl->sdl_alen);
		if (strcmp(r->ifr_name, "lo0") == 0 && sdl->sdl_type == IFT_LOOP &&
		    sdl->sdl_alen == 0 && sdl->sdl_index > 0)
			link = 1;
	}
	if (!link) { printf("IFC L FAIL link %d\n", n); return 1; }
	printf("IFC L ok\n");
	return 0;
}

/* -s addr: does a datagram to addr leave?  ip_output answers ENETUNREACH
 * when no route covers it. */
static int
smode(a)
	char *a;
{
	struct sockaddr_in to;
	int s, r;

	s = socket(AF_INET, SOCK_DGRAM, 0);
	bzero((char *)&to, sizeof to);
	to.sin_family = AF_INET;
	to.sin_port = htons(7);
	to.sin_addr.s_addr = inet_addr(a);
	r = sendto(s, "x", 1, 0, (struct sockaddr *)&to, sizeof to) == 1 ? 0 : errno;
	close(s);
	if (r == 0)
		printf("IFC S %s sent\n", a);
	else
		printf("IFC S %s errno %d\n", a, r);
	return 0;
}

int
main(argc, argv)
	int argc;
	char **argv;
{
	char buf[256];
	struct ifconf ifc;
	struct ifreq ifr, *r;
	struct sockaddr_in *sin;
	int s, n, i, sawlo;

	if (argc > 1 && strcmp(argv[1], "-l") == 0)
		return lmode();
	if (argc > 2 && strcmp(argv[1], "-s") == 0)
		return smode(argv[2]);
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
		if (strcmp(r->ifr_name, "lo0") == 0 && sin->sin_family != AF_LINK) {
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
	else if (ifr.ifr_flags != (IFF_UP|IFF_LOOPBACK))	/* 2.11BSD if_loop.c: */
		fail("flags-val", (long)ifr.ifr_flags);		/* never RUNNING */

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

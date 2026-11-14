/* bsdnet_init -- the C entered once, when the last network module has loaded
 * and every bank is linked, in the order of 2.11BSD's netstart() in
 * sys/sys_net.c: mbinit, the interfaces, ifinit, then domaininit, which "must
 * follow interfaces".  lo0 then takes its address, which upstream leaves to
 * ifconfig in /etc/rc.  Returns 0, or the number of the first failed probe case;
 * mod_init logs which. */
#include "param.h"
#include "mbuf.h"
#include "domain.h"
#include "protosw.h"
#include "ioctl.h"
#include "socket.h"
#include "../net/if.h"
#include "../netinet/in.h"

extern int mbinit(), domaininit(), net_hookinit(), net_stack_paint();
extern int loattach(), ifinit(), in_control(), w5attach();
extern void net_calloutinit();
extern struct ifnet loif;
#ifdef NETPROBE
extern int netprobe();
#endif

static int
lo_up()
{
	struct ifreq ifr;
	register struct sockaddr_in *sin;

	bzero((caddr_t)&ifr, sizeof(ifr));
	sin = (struct sockaddr_in *)&ifr.ifr_addr;
	sin->sin_family = AF_INET;
	sin->sin_addr.s_addr = htonl(0x7f000001L);
	return (in_control((struct socket *)0, SIOCSIFADDR, (caddr_t)&ifr, &loif));
}

int
bsdnet_init()
{
	int s;

	net_stack_paint();
	net_hookinit();		/* first: the initializers below may schedule */
	net_calloutinit();
	mbinit();
	(void) w5attach();
	loattach();
	s = splimp();
	ifinit();
	domaininit();
	splx(s);
	if (lo_up() != 0)
		panic("lo0: no address");
#ifdef NETPROBE
	return (netprobe());
#else
	return (0);
#endif
}

/* netprobe6 -- an ICMP echo through the real IP path, over lo0 first and the
 * wire later.  net_echo sends; the answer arrives at the drain, so the hook
 * samples the counters and logs. */
#include "param.h"
#include "mbuf.h"
#include "domain.h"
#include "protosw.h"
#include "socket.h"
#include "errno.h"
#include "../net/if.h"
#include "../net/route.h"
#include "../net/netisr.h"
#include "../netinet/in.h"
#include "../netinet/in_systm.h"
#include "../netinet/in_var.h"
#include "../netinet/ip.h"
#include "../netinet/ip_var.h"
#include "../netinet/ip_icmp.h"
#include "../netinet/icmp_var.h"

extern	struct ifnet loif;
extern	int in_cksum(), ip_output();
extern	int net_stack_hwm();
extern	int kc_printstr();

#define	LOOPBACK	0x7f000001L
#define	ECHO_LEN	(sizeof(struct ip) + ICMP_MINLEN)

static	u_long np_echo0, np_reply0, np_badsum0;
static	int np6_state;

/* A 16-bit number in a log line. */
void
np_logn(s, n, tail)
	char *s;
	int n;
	char *tail;
{
	static char buf[48];
	register char *p, *q;
	register int d;
	int div;

	p = buf;
	for (q = s; *q; q++)
		*p++ = *q;
	for (div = 10000; div > 0; div /= 10) {
		d = (n / div) % 10;
		if (d || div == 1 || p[-1] != ' ')
			*p++ = '0' + d;
	}
	for (q = tail; *q; q++)
		*p++ = *q;
	*p = 0;
	kc_printstr(buf);
}

/* Send an ICMP echo request to dst, in host order. */
int
net_echo(dst)
	u_long dst;
{
	register struct mbuf *m;
	register struct ip *ip;
	register struct icmp *icp;

	m = m_getclr(M_DONTWAIT, MT_HEADER);
	if (m == 0)
		return (ENOBUFS);
	m->m_len = ECHO_LEN;
	ip = mtod(m, struct ip *);
	ip->ip_len = ECHO_LEN;
	ip->ip_ttl = MAXTTL;
	ip->ip_p = IPPROTO_ICMP;
	ip->ip_dst.s_addr = htonl(dst);
	icp = (struct icmp *)(ip + 1);
	icp->icmp_type = ICMP_ECHO;
	icp->icmp_id = 0x4647;
	icp->icmp_seq = 1;
	m->m_off += sizeof(struct ip);
	m->m_len -= sizeof(struct ip);
	icp->icmp_cksum = in_cksum(m, ICMP_MINLEN);
	m->m_off -= sizeof(struct ip);
	m->m_len += sizeof(struct ip);
	return (ip_output(m, (struct mbuf *)0, (struct route *)0, 0));
}

/* 42: an echo whose IP header checksum is wrong, handed straight to ipintr. */
static int
bad_header()
{
	register struct mbuf *m;
	register struct ip *ip;
	struct ifnet **ifpp;

	m = m_getclr(M_DONTWAIT, MT_HEADER);
	if (m == 0)
		return (ENOBUFS);
	m->m_len = sizeof(struct ifnet *) + ECHO_LEN;
	ifpp = mtod(m, struct ifnet **);
	*ifpp = &loif;
	ip = (struct ip *)(ifpp + 1);
	ip->ip_v = IPVERSION;
	ip->ip_hl = sizeof(struct ip) >> 2;
	ip->ip_len = htons(ECHO_LEN);
	ip->ip_ttl = MAXTTL;
	ip->ip_p = IPPROTO_ICMP;
	ip->ip_src.s_addr = htonl(LOOPBACK);
	ip->ip_dst.s_addr = htonl(LOOPBACK);
	ip->ip_sum = 0x1234;
	IF_ENQUEUE(&ipintrq, m);
	schednetisr(NETISR_IP);
	return (0);
}

/* Called from the hook on every netintr entry. */
void
np6_sample()
{
	switch (np6_state) {
	case 1:
		/* Two passes of the same drain deliver the echo and its reply. */
		if (icmpstat.icps_inhist[ICMP_ECHO] == np_echo0 + 1 &&
		    icmpstat.icps_inhist[ICMP_ECHOREPLY] == np_reply0 + 1) {
			kc_printstr("bsdnet: lo0 echo ok");
			np_logn("bsdnet: net stack ", net_stack_hwm(), " of 1024");
			np_echo0 = icmpstat.icps_inhist[ICMP_ECHO];
			np_badsum0 = ipstat.ips_badsum;
			if (bad_header() != 0)
				kc_printstr("bsdnet: BROKEN 42");
			np6_state = 2;
		}
		break;
	case 2:
		if (ipstat.ips_badsum == np_badsum0 + 1) {
			if (icmpstat.icps_inhist[ICMP_ECHO] != np_echo0)
				kc_printstr("bsdnet: BROKEN 42");
			else
				kc_printstr("bsdnet: bad checksum refused");
			np6_state = 3;
		}
		break;
	}
}

int
netprobe6()
{
	/* 40: lo0 has come up with its address, in a structure that fits an mbuf */
	if ((loif.if_flags & IFF_UP) == 0 || loif.if_addrlist == 0)
		return (40);
	if (sizeof(struct in_ifaddr) > MLEN)
		return (40);
	/* 41: the answer arrives at the drain */
	np_echo0 = icmpstat.icps_inhist[ICMP_ECHO];
	np_reply0 = icmpstat.icps_inhist[ICMP_ECHOREPLY];
	if (net_echo((u_long)LOOPBACK) != 0)
		return (41);
	np6_state = 1;
	return (0);
}

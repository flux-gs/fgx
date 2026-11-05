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
#include "../netinet/if_ether.h"
#include "../netinet/icmp_var.h"

extern	struct ifnet loif;
extern	struct arpcom w5_ac;
extern	int w5_force_badlen;
extern	long w5_iqdrops;
extern	int w5_hold;
extern	struct arptab arptab[];
extern	int arptab_size;
extern	int kc_ticks();
extern	void w5_lock(), w5_unlock(), w5_setar(), w5_rxcopy();
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
		d = ((unsigned)n / div) % 10;
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

/* 48: ARP and echo on the wire, to the gateway the chip holds, then 44: a burst
 * of replies into a ring that is not being drained.  At kernel.netprobe = 4 the
 * target is an unused LAN address instead, so ARP goes unanswered. */
#define	BURST		45
#define	NP_NOREPLY	0xC8		/* a host number nothing here uses */
static int w5_state;
static u_long np_gw;
static long np_now, np_t;
static long np_rx0, np_err0;
static u_long np_rep0;
static long np_rxlast, np_tlast;

static struct arptab *
arpfind(hostaddr)
	u_long hostaddr;
{
	register int i;
	u_long a;

	a = htonl(hostaddr);
	for (i = 0; i < arptab_size; i++)
		if (arptab[i].at_iaddr.s_addr == a)
			return (&arptab[i]);
	return ((struct arptab *)0);
}

static void
logmac(at)
	register struct arptab *at;
{
	static char msg[] = "bsdnet: arp resolved 00:00:00:00:00:00";
	static char hex[] = "0123456789abcdef";
	register int i;
	register char *p = msg + 21;

	for (i = 0; i < 6; i++, p += 3) {
		p[0] = hex[(at->at_enaddr[i] >> 4) & 15];
		p[1] = hex[at->at_enaddr[i] & 15];
	}
	kc_printstr(msg);
}

static int
wire_start()
{
	static u_long gar;

	w5_lock();
	w5_setar(1);		/* GAR */
	w5_rxcopy((char *)&gar, 4);
	w5_unlock();
	np_gw = ntohl(gar);
#if NETPROBE == 4
	np_gw = (np_gw & 0xFFFFFF00L) | NP_NOREPLY;
#endif
	np_rep0 = icmpstat.icps_inhist[ICMP_ECHOREPLY];
	if (net_echo(np_gw) != 0)
		kc_printstr("bsdnet: BROKEN 48");
#if NETPROBE == 4
	return (10);
#else
	return (4);
#endif
}

static void
noreply_sample()
{
	/* The ager clears an incomplete entry after ARPT_KILLI minutes. */
	if (arpfind(np_gw) != 0)
		return;
	if (icmpstat.icps_inhist[ICMP_ECHOREPLY] != np_rep0)
		kc_printstr("bsdnet: BROKEN 48");
	else
		kc_printstr("bsdnet: arp unresolved");
	w5_state = 11;
}

static void
wire_sample()
{
	register struct ifnet *ifp = &w5_ac.ac_if;
	register struct arptab *at;
	register int i;

	kc_ticks(&np_now);
	switch (w5_state) {
	case 4:		/* the echo that had to wait for ARP */
		if (icmpstat.icps_inhist[ICMP_ECHOREPLY] == np_rep0)
			break;
		at = arpfind(np_gw);
		if (at == 0)
			kc_printstr("bsdnet: BROKEN 48");
		else
			logmac(at);
		kc_printstr("bsdnet: echo reply from gateway");
		np_rep0 = icmpstat.icps_inhist[ICMP_ECHOREPLY];
		np_t = np_now;
		(void) net_echo(np_gw);
		w5_state = 5;
		break;
	case 5:		/* one with ARP resolved: the round trip */
		if (icmpstat.icps_inhist[ICMP_ECHOREPLY] == np_rep0)
			break;
		np_logn("bsdnet: echo rtt ", (int)(np_now - np_t), " ticks");
		np_rx0 = ifp->if_ipackets;
		np_err0 = ifp->if_ierrors;
		w5_hold = 1;
		for (i = 0; i < BURST; i++)
			(void) net_echo(np_gw);
		np_t = np_now;
		w5_state = 6;
		break;
	case 6:		/* sent, and two seconds for the answers */
		if (ifp->if_snd.ifq_head != 0) {
			np_t = np_now;
			break;
		}
		if (np_now - np_t < 120L)
			break;
		w5_hold = 0;
		np_t = np_now;
		np_tlast = np_now;
		np_rxlast = ifp->if_ipackets;
		w5_state = 7;
		break;
	case 7:		/* a second to drain, measured */
		if (ifp->if_ipackets != np_rxlast) {
			np_rxlast = ifp->if_ipackets;
			np_tlast = np_now;
		}
		if (np_now - np_t < 60L)
			break;
		np_logn("bsdnet: burst drained in ticks ", (int)(np_tlast - np_t), "");
		np_logn("bsdnet: burst of 45 got ", (int)(ifp->if_ipackets - np_rx0),
		    " frames");
		np_logn("bsdnet: burst errors ", (int)(ifp->if_ierrors - np_err0), "");
		if (ifp->if_ierrors == np_err0 &&
		    ifp->if_ipackets - np_rx0 >= (long)BURST)
			kc_printstr("bsdnet: BROKEN 44");
		np_rep0 = icmpstat.icps_inhist[ICMP_ECHOREPLY];
		(void) net_echo(np_gw);
		w5_state = 8;
		break;
	case 8:
		if (icmpstat.icps_inhist[ICMP_ECHOREPLY] == np_rep0)
			break;
		kc_printstr("bsdnet: alive after burst");
		np_logn("bsdnet: net stack ", net_stack_hwm(), " of 1024");
		w5_state = 9;
		break;
	}
}

/* 43, 45, 46, each on the next frame the LAN happens to send. */
static long np_ierr0, np_drop0;
static struct mbuf *np_hoard;

static void
w5_sample()
{
	register struct ifnet *ifp = &w5_ac.ac_if;
	register struct mbuf *m;

	if ((ifp->if_flags & IFF_UP) == 0)
		return;
	switch (w5_state) {
	case 0:
		if (ifp->if_ipackets == 0)
			break;
		kc_printstr("bsdnet: w5 received");
		np_ierr0 = ifp->if_ierrors;
		w5_force_badlen = 1;
		w5_state = 1;
		break;
	case 1:
		if (ifp->if_ierrors == np_ierr0)
			break;
		kc_printstr("bsdnet: w5 bad length reopened");
		np_drop0 = w5_iqdrops;
		while ((m = m_get(M_DONTWAIT, MT_DATA)) != 0) {
			m->m_next = np_hoard;
			np_hoard = m;
		}
		w5_state = 2;
		break;
	case 2:
		if (w5_iqdrops == np_drop0)
			break;
		m_freem(np_hoard);
		np_hoard = 0;
		kc_printstr("bsdnet: w5 pool empty dropped");
		w5_state = wire_start();
		break;
	case 4:
	case 5:
	case 6:
	case 7:
	case 8:
	case 9:
		wire_sample();
		break;
	case 10:
		noreply_sample();
		break;
	}
}

/* Called from the hook on every netintr entry. */
int
np6_sample()
{
	w5_sample();
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
	return (0);
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

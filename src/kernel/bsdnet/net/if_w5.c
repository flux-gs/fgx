/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/pdpif/if_de.c
 *   Written for FGX after deoutput, destart, deread, deget and deioctl in
 *   usr/sys/pdpif/if_de.c, 2.11BSD.  Original work:
 *   Copyright (c) 1982, 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* if_w5.c -- the Uthernet II's W5100 as an Ethernet interface, on socket 0 in
 * MACRAW mode.  Nothing here runs from an interrupt: the ISR marks the drain, and
 * netintr calls w5rint, which also polls, so a lost interrupt costs 133 ms. */
#include "param.h"
#include "mbuf.h"
#include "domain.h"
#include "protosw.h"
#include "ioctl.h"
#include "socket.h"
#include "errno.h"
#include "../net/if.h"
#include "../net/netisr.h"
#include "../net/route.h"
#include "../netinet/in.h"
#include "../netinet/in_systm.h"
#include "../netinet/in_var.h"
#include "../netinet/ip.h"
#include "../netinet/if_ether.h"

#define	W5_SHAR		0x0009
#define	W5_RMSR		0x001A	/* socket 0's RX size in bits 1-0: 1 KB << n */
#define	S0_MR		0x0400
#define	S0_CR		0x0401
#define	S0_SR		0x0403
#define	S0_TX_FSR	0x0420
#define	S0_TX_WR	0x0424
#define	S0_RX_RSR	0x0426
#define	S0_RX_RD	0x0428
#define	MR_MACRAW_MF	0x44
#define	SR_MACRAW	0x42
#define	CR_OPEN		0x01
#define	CR_CLOSE	0x10
#define	CR_SEND		0x20
#define	CR_RECV		0x40
#define	W5_TXBASE	0x4000
#define	W5_RXBASE	0x6000
#define	W5_RINGSIZE	0x2000	/* all 8 KB each way: RMSR and TMSR at $03 */
#define	W5_RINGMASK	(W5_RINGSIZE - 1)

#define	W5_MINFRAME	60	/* an Ethernet minimum, without the FCS */
#define	W5_MAXBURST	8	/* frames a drain takes before asking for another */

extern	int w5_init(), w5_claim0(), w5_rreg(), w5_rreg16();
extern	void w5_lock(), w5_unlock(), w5_arm(), w5_setpb(), w5_setar();
extern	void w5_wreg(), w5_wreg16(), w5_rxcopy(), w5_txcopy();
extern	void kc_printstr(), setsoftnet();
extern	int arpresolve(), arpwhohas(), in_control(), if_attach(), rtinit();
extern	int arpinput();

int	w5_slotx;		/* the slot, shifted; w5_asm.s reads it */
unsigned w5_end;		/* where a w5_asm.s copy stops */

struct	arpcom w5_ac;
long	w5_iqdrops;		/* frames with no mbuf to go into */
static	int w5_up;
#ifdef NETPROBE
int	w5_force_badlen;	/* the probe's seams: a nonsense length, once */
int	w5_hold;		/* no draining, so the ring overruns */
int	w5_txhold;		/* frames stay queued, to leave together */
int	w5_force_torn;		/* one torn read of RSR */
#endif

int w5output(), w5ioctl();

/* What bpf.mod reads while the stack holds socket 0: a ring of records in netdump's
 * shape, {caplen.w, datalen.w, frame...}, found through bsdnetd's vtable.  The
 * layout is bpf.s's TAP_* too.  Only task-level code and netintr touch it, and
 * neither interrupts the other. */
#define	TAP_NREC	8
#define	TAP_SNAP	60
struct {
	int	t_up;		/* the driver is attached */
	int	t_active;	/* bpf is open */
	int	t_head, t_tail;
	int	t_sat;		/* frames lost to a full ring */
	char	t_rec[TAP_NREC][4 + TAP_SNAP];
} w5_tapr;

/* The first bytes of a frame: hdr if there is one, then the chain after skip. */
static void
w5_tap(hdr, m, skip, datalen)
	char *hdr;
	register struct mbuf *m;
	int skip, datalen;
{
	register int n, room;
	register char *r;
	int next;

	if (!w5_tapr.t_active)
		return;
	next = (w5_tapr.t_head + 1) & (TAP_NREC - 1);
	if (next == w5_tapr.t_tail) {
		w5_tapr.t_sat++;
		return;
	}
	r = w5_tapr.t_rec[w5_tapr.t_head];
	room = datalen < TAP_SNAP ? datalen : TAP_SNAP;
	((int *)r)[0] = room;
	((int *)r)[1] = datalen;
	r += 4;
	if (hdr) {
		bcopy(hdr, r, sizeof(struct ether_header));
		r += sizeof(struct ether_header);
		room -= sizeof(struct ether_header);
	}
	for (; m && room > 0; m = m->m_next) {
		n = m->m_len - skip;
		if (n > room)
			n = room;
		if (n > 0) {
			bcopy(mtod(m, char *) + skip, r, n);
			r += n;
			room -= n;
		}
		skip = 0;
	}
	w5_tapr.t_head = next;
	selwakeup((struct proc *)0, (long)1);	/* a select on bpf: none recorded */
}

static void
w5_cmd(cmd)
	int cmd;
{
	register int i;

	w5_wreg(S0_CR, cmd);
	for (i = 0; i < 1000; i++)
		if (w5_rreg(S0_CR) == 0)
			break;
}

/* Socket 0 to MACRAW with the MAC filter.  1 if the chip took it. */
static int
w5_open0()
{
	w5_cmd(CR_CLOSE);
	w5_wreg(S0_MR, MR_MACRAW_MF);
	w5_cmd(CR_OPEN);
	return (w5_rreg(S0_SR) == SR_MACRAW);
}

/* A run of the ring into the data bank. */
static void
w5_ringin(off, cp, n)
	unsigned off;
	char *cp;
	int n;
{
	register int first;

	off &= W5_RINGMASK;
	first = W5_RINGSIZE - off;
	if (first > n)
		first = n;
	w5_setar(W5_RXBASE + off);
	w5_rxcopy(cp, first);
	if (n > first) {
		w5_setar(W5_RXBASE);
		w5_rxcopy(cp + first, n - first);
	}
}

static void
w5_ringout(off, cp, n)
	unsigned off;
	char *cp;
	int n;
{
	register int first;

	off &= W5_RINGMASK;
	first = W5_RINGSIZE - off;
	if (first > n)
		first = n;
	w5_setar(W5_TXBASE + off);
	w5_txcopy(cp, first);
	if (n > first) {
		w5_setar(W5_TXBASE);
		w5_txcopy(cp + first, n - first);
	}
}

static void
w5_logmac()
{
	static char msg[] = "w5: attached, 00:00:00:00:00:00, rx 0000";
	static char hex[] = "0123456789abcdef";
	register int i;
	register char *p = msg + 14;
	unsigned sz;

	for (i = 0; i < 6; i++, p += 3) {
		p[0] = hex[(w5_ac.ac_enaddr[i] >> 4) & 15];
		p[1] = hex[w5_ac.ac_enaddr[i] & 15];
	}
	/* socket 0's receive buffer, as the chip has it */
	sz = 1024 << (w5_rreg(W5_RMSR) & 3);
	p = msg + sizeof(msg) - 2;
	for (i = 0; i < 4; i++, sz /= 10)
		*p-- = '0' + sz % 10;
	kc_printstr(msg);
}

/* Name the interface, take the socket.  0 and no interface if there is no card
 * or a hardware connection holds socket 0, and lo0 serves alone. */
int
w5attach()
{
	register struct ifnet *ifp = &w5_ac.ac_if;
	static char sh[6];
	int ok;

	if (w5_init() == 0) {
		kc_printstr("w5: no card, lo0 only");
		return (0);
	}
	if (w5_claim0()) {
		kc_printstr("w5: socket 0 busy");
		return (0);
	}
	w5_lock();
	w5_setpb();
	ok = w5_open0();
	w5_setar(W5_SHAR);
	w5_rxcopy(sh, 6);
	w5_arm();
	w5_unlock();
	if (!ok) {
		kc_printstr("w5: socket 0 will not open");
		return (0);
	}
	bcopy((caddr_t)sh, (caddr_t)w5_ac.ac_enaddr, 6);
	w5_logmac();
	ifp->if_name = "wz";
	ifp->if_mtu = ETHERMTU;
	ifp->if_flags = IFF_BROADCAST | IFF_NOTRAILERS;
	ifp->if_ioctl = w5ioctl;
	ifp->if_output = w5output;
	if_attach(ifp);
	w5_up = 1;
	w5_tapr.t_up = 1;
	return (1);
}

/* The broadcast address's host route, kept so the next address can delete it:
 * rtrequest deletes only a route whose gateway matches (net/route.c). */
u_long	w5_rtaddr;			/* the probe reads it */
static	int w5_routed;

static void
w5route(dst, gw, cmd, flags)
	u_long dst, gw;
	int cmd, flags;
{
	struct sockaddr_in d, g;

	bzero((caddr_t)&d, sizeof(d));
	bzero((caddr_t)&g, sizeof(g));
	d.sin_family = g.sin_family = AF_INET;
	d.sin_addr.s_addr = dst;
	g.sin_addr.s_addr = gw;
	(void) rtinit((struct sockaddr *)&d, (struct sockaddr *)&g, cmd, flags);
}

/* As deioctl's SIOCSIFADDR. */
int
w5ioctl(ifp, cmd, data)
	register struct ifnet *ifp;
	int cmd;
	caddr_t data;
{
	register struct ifaddr *ifa = (struct ifaddr *)data;

	if (cmd != SIOCSIFADDR)
		return (EINVAL);
	ifp->if_flags |= IFF_UP | IFF_RUNNING;
	if (ifa->ifa_addr.sa_family == AF_INET) {
		w5_ac.ac_ipaddr = IA_SIN(ifa)->sin_addr;
		if (w5_ac.ac_ipaddr.s_addr != INADDR_ANY)	/* none for 0.0.0.0 */
			arpwhohas(&w5_ac, &IA_SIN(ifa)->sin_addr);
		/*
		 * 255.255.255.255 to this interface, through its new address.
		 * in_pcbconnect sends INADDR_BROADCAST to the PRIMARY interface's
		 * broadcast address, and the primary is lo0, so without this host
		 * route a DHCP DISCOVER from 0.0.0.0 would not leave by the card,
		 * and once there is an address it would follow the default route
		 * to the router.  No address yet is 0.0.0.0, as early BOOTP
		 * clients configured: in_ifinit (netinet/in.c) routes network 0
		 * to the interface, and in_netof of 255.255.255.255 is 0.
		 */
		if (w5_routed)
			w5route(INADDR_BROADCAST, w5_rtaddr, SIOCDELRT, RTF_HOST);
		w5_rtaddr = w5_ac.ac_ipaddr.s_addr;
		w5route(INADDR_BROADCAST, w5_rtaddr, SIOCADDRT, RTF_HOST);
		w5_routed = 1;
	}
	return (0);
}

/* Copy queued frames to the transmit ring.  The chip sends one at a time, and its
 * free count is back to a full ring when it has, so each frame waits for the one
 * before it, for at most W5_TXPOLLS reads of the free count.
 * ponytail: a read of the free count is 23 us (8000 in 11 ticks), so W5_TXPOLLS
 * is 3 ms, over the 1.2 ms a full frame takes on a 10 Mb wire; past it the frame
 * waits for the next netintr entry.  S4 revisits this with 8 KB transmit buffers. */
#define	W5_TXPOLLS	130
void
w5start()
{
	register struct mbuf *m, *n;
	register int len;
	unsigned wr;
	static char zeros[W5_MINFRAME];
	int s, polls;

#ifdef NETPROBE
	if (w5_txhold)
		return;
#endif
	while (w5_up && w5_ac.ac_if.if_snd.ifq_head) {
		w5_lock();
		for (polls = 0; (unsigned)w5_rreg16(S0_TX_FSR) != W5_RINGSIZE; polls++)
			if (polls >= W5_TXPOLLS) {
				w5_unlock();
				return;
			}
		s = splimp();
		IF_DEQUEUE(&w5_ac.ac_if.if_snd, m);
		splx(s);
		wr = w5_rreg16(S0_TX_WR);
		len = 0;
		for (n = m; n; n = n->m_next) {
			w5_ringout(wr + len, mtod(n, char *), n->m_len);
			len += n->m_len;
		}
		if (len < W5_MINFRAME) {
			w5_ringout(wr + len, zeros, W5_MINFRAME - len);
			len = W5_MINFRAME;
		}
		w5_wreg16(S0_TX_WR, wr + len);
		w5_cmd(CR_SEND);
		w5_unlock();
		w5_ac.ac_if.if_opackets++;
		w5_tap((char *)0, m, 0, len);
		m_freem(m);
	}
}

/* As deoutput, with no trailers. */
int
w5output(ifp, m0, dst)
	struct ifnet *ifp;
	struct mbuf *m0;
	struct sockaddr *dst;
{
	int type, s, error, usetrailers;
	static u_char edst[6];
	struct in_addr idst;
	register struct mbuf *m = m0;
	register struct ether_header *eh;

	if ((ifp->if_flags & (IFF_UP|IFF_RUNNING)) != (IFF_UP|IFF_RUNNING)) {
		error = ENETDOWN;
		goto bad;
	}
	switch (dst->sa_family) {

	case AF_INET:
		idst = ((struct sockaddr_in *)dst)->sin_addr;
		if (!arpresolve(&w5_ac, m, &idst, edst, &usetrailers))
			return (0);	/* if not yet resolved */
		type = ETHERTYPE_IP;
		break;

	case AF_UNSPEC:
		eh = (struct ether_header *)dst->sa_data;
		bcopy((caddr_t)eh->ether_dhost, (caddr_t)edst, sizeof(edst));
		type = eh->ether_type;
		break;

	default:
		printf("w5: can't handle this address family");
		error = EAFNOSUPPORT;
		goto bad;
	}

	if (m->m_off > MMAXOFF ||
	    MMINOFF + sizeof(struct ether_header) > m->m_off) {
		m = m_get(M_DONTWAIT, MT_HEADER);
		if (m == 0) {
			error = ENOBUFS;
			goto bad;
		}
		m->m_next = m0;
		m->m_off = MMINOFF;
		m->m_len = sizeof(struct ether_header);
	} else {
		m->m_off -= sizeof(struct ether_header);
		m->m_len += sizeof(struct ether_header);
	}
	eh = mtod(m, struct ether_header *);
	eh->ether_type = htons((u_short)type);
	bcopy((caddr_t)edst, (caddr_t)eh->ether_dhost, sizeof(edst));
	bcopy((caddr_t)w5_ac.ac_enaddr, (caddr_t)eh->ether_shost, 6);

	s = splimp();
	if (IF_QFULL(&ifp->if_snd)) {
		IF_DROP(&ifp->if_snd);
		splx(s);
		m_freem(m);
		return (ENOBUFS);
	}
	IF_ENQUEUE(&ifp->if_snd, m);
	splx(s);
	w5start();
	return (0);
bad:
	m_freem(m0);
	return (error);
}

/* The frame's data, from the ring, as deget: the interface pointer ipintr expects
 * goes first. */
static struct mbuf *
w5get(off, totlen)
	unsigned off;
	register int totlen;
{
	struct mbuf *top, *m;
	register struct mbuf **mp;
	register int len;
	struct ifnet *ifp = &w5_ac.ac_if;

	top = 0;
	mp = &top;
	while (totlen > 0) {
		MGET(m, M_DONTWAIT, MT_DATA);
		if (m == 0)
			goto bad;
		*mp = m;	/* m_freem at bad gets it, cluster or not */
		m->m_off = MMINOFF;
		len = MLEN;
		if (ifp) {
			m->m_off += sizeof(ifp);
			len -= sizeof(ifp);
		}
		if (totlen > len) {
			MCLGET(m);
			if (m->m_len == MCLBYTES) {
				len = MCLBYTES;
				if (ifp) {
					m->m_off += sizeof(ifp);
					len -= sizeof(ifp);
				}
			}
		}
		if (len > totlen)
			len = totlen;
		m->m_len = len;
		w5_ringin(off, mtod(m, char *), len);
		off += len;
		totlen -= len;
		if (ifp) {
			m->m_off -= sizeof(ifp);
			m->m_len += sizeof(ifp);
			*(mtod(m, struct ifnet **)) = ifp;
			ifp = (struct ifnet *)0;
		}
		mp = &m->m_next;
	}
	return (top);
bad:
	m_freem(top);
	return ((struct mbuf *)0);
}

/* As deread's dispatch. */
static void
w5input(eh, m)
	register struct ether_header *eh;
	struct mbuf *m;
{
	register struct ifqueue *inq;
	int s;

	switch (ntohs((u_short)eh->ether_type)) {

	case ETHERTYPE_IP:
		schednetisr(NETISR_IP);
		inq = &ipintrq;
		break;

	case ETHERTYPE_ARP:
		/* At 0.0.0.0 every RFC 5227 probe on the LAN (sender 0.0.0.0)
		 * would match our address in in_arpinput, be logged as a
		 * duplicate and answered.  DHCP needs no ARP; drop them. */
		if (w5_ac.ac_ipaddr.s_addr == INADDR_ANY) {
			m_freem(m);
			return;
		}
		arpinput(&w5_ac, m);
		return;

	default:
		m_freem(m);
		return;
	}
	s = splimp();
	if (IF_QFULL(inq)) {
		IF_DROP(inq);
		splx(s);
		m_freem(m);
		return;
	}
	IF_ENQUEUE(inq, m);
	splx(s);
}

/* Sn_RX_RSR, read until two reads agree.  The chip updates it as frames land, and
 * a pair of byte reads across a change to the high byte comes back 256 short,
 * which looks like a nonsense length and would cost the whole ring. */
static unsigned
w5_rsr()
{
	register unsigned a, b;

	b = w5_rreg16(S0_RX_RSR);
	do {
		a = b;
#ifdef NETPROBE
		if (w5_force_torn) {
			w5_force_torn = 0;
			a = 1;
		}
#endif
		b = w5_rreg16(S0_RX_RSR);
	} while (a != b);
	return (a);
}

/* A frame the stack has no use for: one to a group address other than broadcast,
 * which the chip's filter passes and the DEUNA's does not, or one of a type
 * w5input frees. */
static int
w5_unwanted(eh)
	register struct ether_header *eh;
{
	if ((eh->ether_dhost[0] & 1) &&
	    bcmp((caddr_t)eh->ether_dhost, (caddr_t)etherbroadcastaddr,
	    sizeof(eh->ether_dhost)))
		return (1);
	switch (ntohs((u_short)eh->ether_type)) {
	case ETHERTYPE_IP:
	case ETHERTYPE_ARP:
		return (0);
	}
	return (1);
}

/* Drain the receive ring, at most W5_MAXBURST frames a pass. */
void
w5rint()
{
	static unsigned char hdr[2];
	static struct ether_header eh;
	register struct ifnet *ifp = &w5_ac.ac_if;
	register int frames;
	unsigned rd, rsr, len;
	struct mbuf *m;

	if (!w5_up)
		return;
#ifdef NETPROBE
	if (w5_hold) {
		w5start();
		return;
	}
#endif
	for (frames = 0; frames < W5_MAXBURST; frames++) {
		w5_lock();
		rsr = w5_rsr();
		if (rsr == 0) {
			w5_arm();
			w5_unlock();
			w5start();
			return;
		}
		/* The chip has no drop counter.  A ring within a minimum frame of full
		 * is dropping, as bpf.mod's saturation count says too. */
		if (rsr >= W5_RINGSIZE - 0x40)
			ifp->if_ierrors++;
		rd = w5_rreg16(S0_RX_RD);
		w5_ringin(rd, (char *)hdr, 2);
		len = ((unsigned)hdr[0] << 8) | hdr[1];
#ifdef NETPROBE
		if (w5_force_badlen) {
			w5_force_badlen = 0;
			len = 0xFFF0;
		}
#endif
		/* The length includes itself.  A nonsense one means the ring cannot be
		 * trusted, so the socket starts over and the ring with it. */
		if (len < 2 + sizeof(eh) || len > 2 + sizeof(eh) + ETHERMTU + 4 ||
		    len > rsr) {
			(void) w5_open0();
			w5_arm();
			w5_unlock();
			ifp->if_ierrors++;
			return;
		}
		w5_ringin(rd + 2, (char *)&eh, sizeof(eh));
		/* An unwanted frame is passed over in the ring, unread past its
		 * header, unless bpf is open: netdump shows the wire. */
		if (!w5_tapr.t_active && w5_unwanted(&eh)) {
			w5_wreg16(S0_RX_RD, rd + len);
			w5_cmd(CR_RECV);
			w5_unlock();
			continue;
		}
		m = w5get(rd + 2 + sizeof(eh), (int)len - 2 - (int)sizeof(eh));
		w5_wreg16(S0_RX_RD, rd + len);
		w5_cmd(CR_RECV);
		w5_unlock();
		if (m == 0) {
			w5_iqdrops++;
			ifp->if_ierrors++;
			continue;
		}
		ifp->if_ipackets++;
		w5_tap((char *)&eh, m, sizeof(struct ifnet *), (int)len - 2);
		w5input(&eh, m);
	}
	setsoftnet();		/* more may be waiting */
	w5start();
}

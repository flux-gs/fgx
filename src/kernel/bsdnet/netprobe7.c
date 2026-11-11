/* netprobe7 -- S3's cases: what a process needs from the stack.  setjmp and
 * longjmp in the kernel, and the stack's errno agreeing with userland's. */
#include "param.h"
#include "user.h"
#include "errno.h"
#include "mbuf.h"
#include "domain.h"
#include "protosw.h"
#include "socket.h"
#include "../net/if.h"
#include "../net/route.h"
#include "../netinet/in.h"
#include "../netinet/if_ether.h"

extern	struct arpcom w5_ac;
extern	u_long w5_rtaddr, w5_rtmask, w5_rtgw;
extern	int w5setaddr(), kc_printstr();

/* 52: one would-block errno, userland's (include/errno.s, toolchain errno.h). */
#if EWOULDBLOCK != EAGAIN
#include "netprobe7: EWOULDBLOCK must be EAGAIN"
#endif

static	label_t np7_env;
static	int np7_depth;

static void
np7_jump(n)
	int n;
{
	int mine;

	mine = np7_peek(&n);	/* a frame of its own in _fcc_fb */
	if (mine > 0) {
		np7_depth++;
		np7_jump(n - 1);
	}
	longjmp(&np7_env, 7);
}

static int
np7_peek(p)
	int *p;
{
	return (*p);
}

/* After the longjmp a local's address is taken afresh, which fcc builds from
 * _fcc_fb: np7_jump left its own frame there, so this reads the right local only
 * if longjmp put setjmp's back.  The pointer taken before the setjmp, and the
 * register local, are read back too. */
static int
np7_setjmp()
{
	register int kept;
	int seen, *where;

	kept = 0x5a5a;
	seen = 11;
	where = &seen;
	np7_depth = 0;
	if (setjmp(&np7_env)) {
		if (kept != 0x5a5a || *where != 11 || np7_peek(&seen) != 11 ||
		    np7_depth != 3)
			return (51);
		return (0);
	}
	seen = 11;
	np7_jump(3);
	return (51);		/* longjmp came back here */
}

/* The route rtalloc finds for dst: its gateway, or 0 with no RTF_GATEWAY,
 * and -1 for none.  *hostp says whether it was a host route on w5. */
static long
np7_route(dst, hostp)
	u_long dst;
	int *hostp;
{
	struct route ro;
	register struct rtentry *rt;
	long gw;

	bzero((caddr_t)&ro, sizeof(ro));
	ro.ro_dst.sa_family = AF_INET;
	((struct sockaddr_in *)&ro.ro_dst)->sin_addr.s_addr = dst;
	rtalloc(&ro);
	if ((rt = ro.ro_rt) == 0)
		return (-1L);
	*hostp = (rt->rt_flags & RTF_HOST) && rt->rt_ifp == &w5_ac.ac_if;
	gw = (rt->rt_flags & RTF_GATEWAY) ?
	    (long)((struct sockaddr_in *)&rt->rt_gateway)->sin_addr.s_addr : 0L;
	RTFREE(rt);
	return (gw);
}

/* How many default routes, and the gateway of the last one seen. */
static int
np7_defaults(gwp)
	u_long *gwp;
{
	register struct mbuf *m;
	register struct rtentry *rt;
	int i, n;

	n = 0;
	for (i = 0; i < RTHASHSIZ; i++)
		for (m = rtnet[i]; m; m = m->m_next) {
			rt = mtod(m, struct rtentry *);
			if (((struct sockaddr_in *)&rt->rt_dst)->sin_addr.s_addr
			    == INADDR_ANY && (rt->rt_flags & RTF_GATEWAY)) {
				n++;
				*gwp = ((struct sockaddr_in *)&rt->rt_gateway)->sin_addr.s_addr;
			}
		}
	return (n);
}

/* 54: an address off the local net goes through the gateway DHCP gave, and
 * the broadcast address to a host route on w5, not to the gateway.
 * 55: a new gateway replaces the default route rather than adding one.
 * They need the card and an address with a gateway: the netw5 run, where
 * netprobe6's wire start runs them again once dhclient has set one. */
int
np7_routes()
{
	u_long ip, mask, gw, gw2, seen;
	int host;

	if ((w5_ac.ac_if.if_flags & IFF_UP) == 0 || w5_rtgw == 0)
		return (0);
	ip = w5_rtaddr;
	mask = w5_rtmask;
	gw = w5_rtgw;
	host = 0;
	if (np7_route(htonl(0x08080808L), &host) != (long)gw)
		return (54);
	if (np7_route(INADDR_BROADCAST, &host) != 0L || !host)
		return (54);
	gw2 = gw ^ htonl(1L);		/* another address on the same net */
	if (w5setaddr(ip, mask, gw2) != 0)
		return (55);
	seen = 0;
	if (np7_defaults(&seen) != 1 || seen != gw2)
		return (55);
	host = 0;
	if (np7_route(INADDR_BROADCAST, &host) != 0L || !host)
		return (55);
	if (w5setaddr(ip, mask, gw) != 0 || np7_defaults(&seen) != 1 || seen != gw)
		return (55);
	kc_printstr("bsdnet: routes ok");
	return (0);
}

/* 57: in_cksum over a chain agrees with a flat sum of the same bytes, for
 * even and odd segment lengths.  The reference adds little-endian words with
 * an end-around carry, which is the same ones' complement sum. */
extern	int in_cksum();
static	u_char np7_flat[400];

static u_short
np7_refsum(n)
	int n;
{
	register unsigned long sum;
	register int i;

	sum = 0;
	for (i = 0; i + 1 < n; i += 2)
		sum += np7_flat[i] | (np7_flat[i + 1] << 8);
	if (n & 1)
		sum += np7_flat[n - 1];
	while (sum >> 16)
		sum = (sum & 0xffff) + (sum >> 16);
	return ((u_short)~sum);
}

static int
np7_chain(l0, l1, l2, clust)
	int l0, l1, l2, clust;
{
	struct mbuf *m0, *m1, *m2;
	register int i, n;
	int lens[3], k, got, want;
	struct mbuf *ms[3];

	m0 = m_get(M_DONTWAIT, MT_DATA);
	m1 = m_get(M_DONTWAIT, MT_DATA);
	m2 = m_get(M_DONTWAIT, MT_DATA);
	if (m0 == 0 || m1 == 0 || m2 == 0)
		return (0);
	if (clust) {
		MCLGET(m1);
		if (m1->m_len != MCLBYTES)
			return (0);
	}
	m0->m_next = m1; m1->m_next = m2; m2->m_next = 0;
	lens[0] = l0; lens[1] = l1; lens[2] = l2;
	ms[0] = m0; ms[1] = m1; ms[2] = m2;
	n = 0;
	for (k = 0; k < 3; k++) {
		ms[k]->m_len = lens[k];
		for (i = 0; i < lens[k]; i++) {
			np7_flat[n] = (u_char)(n * 37 + 11);
			mtod(ms[k], u_char *)[i] = np7_flat[n];
			n++;
		}
	}
	got = in_cksum(m0, n) & 0xffff;
	want = np7_refsum(n);
	m_freem(m0);
	return (got == want);
}

int
netprobe7()
{
	int r;

	if (!np7_chain(28, 114, 72, 0) || !np7_chain(27, 113, 73, 0) ||
	    !np7_chain(1, 1, 101, 0))
		return (57);
	if (!np7_chain(28, 200, 72, 1) || !np7_chain(27, 201, 72, 1))
		return (58);
	if ((r = np7_setjmp()) != 0)
		return (r);
	return (np7_routes());
}

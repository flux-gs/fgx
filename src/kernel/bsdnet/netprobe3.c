/* netprobe3 -- the mbuf data model, on the machine. */
#include "param.h"
#include "mbuf.h"
#include "protosw.h"
#include "domain.h"
#include "socket.h"
#include "socketvar.h"
#include "../net/if.h"
#include "../net/route.h"
#include "in.h"
#include "in_systm.h"
#include "ip.h"
#include "ip_var.h"
#include "in_pcb.h"
#include "tcp.h"
#include "tcp_timer.h"
#include "tcp_var.h"
#include "tcpip.h"

static int
freecount()
{
	register struct mbuf *m;
	register int n;

	n = 0;
	for (m = mfree; m; m = m->m_next)
		n++;
	return (n);
}

int
netprobe3()
{
	register struct mbuf *m, *n, *hold;
	struct mbuf *c0, *c1, *lo, *hi;
	char *p;
	int total, cnt, i;
	long bank;

	/* 11: the data model */
	if (sizeof(struct mbuf) != 128 || MLEN != 114)
		return (11);
	if (sizeof(struct ipovly) != 20 || sizeof(struct ip) != 20 ||
	    sizeof(struct tcpiphdr) != 40)
		return (11);
	if (sizeof(struct inpcb) > MLEN || sizeof(struct tcpcb) > MLEN ||
	    sizeof(struct socket) > MLEN)
		return (11);
	/* 12: dtom undoes mtod */
	m = m_get(M_DONTWAIT, MT_DATA);
	if (m == 0)
		return (12);
	p = mtod(m, char *);
	if (dtom(p) != m || dtom(p + 1) != m || dtom(p + MLEN - 1) != m)
		return (12);
	/* 13: a cluster above and below its mbuf */
	n = m_get(M_DONTWAIT, MT_DATA);
	if (n == 0)
		return (13);
	lo = (long)m < (long)n ? m : n;
	hi = (long)m < (long)n ? n : m;
	MCLALLOC(c0, 1);
	if (c0 == 0)
		return (13);
	/* the mbuf arrays are below the cluster arrays; wrap by taking a lower
	 * cluster base for hi through m_off arithmetic */
	lo->m_off = (u_int)c0 - (u_int)lo;
	lo->m_len = MCLBYTES;
	if (!M_HASCL(lo) || mtod(lo, struct mbuf *) != c0)
		return (13);
	if ((long)lo >= (long)hi)
		return (16);
	hi->m_off = (u_int)lo - (u_int)hi;	/* lower address: the wrap */
	if (hi->m_off < 0x8000)
		return (17);
	if (mtod(hi, long) != (long)lo)
		return (18);
	if (mtod(hi, struct mbuf *) != lo)
		return (13);
	hi->m_off = MMINOFF;
	total = mbstat.m_clfree;
	(void) m_free(lo);
	if (mbstat.m_clfree != total + 1 || mclfree != c0)
		return (13);
	(void) m_free(hi);
	/* 14: exhaust the pool and refill it */
	total = freecount();
	hold = 0;
	cnt = 0;
	bank = 0;
	while ((m = m_get(M_DONTWAIT, MT_DATA)) != 0) {
		if (cnt == 0)
			bank = (long)m & 0xFFFF0000L;
		else if (((long)m & 0xFFFF0000L) != bank)
			return (14);
		m->m_next = hold;
		hold = m;
		cnt++;
	}
	if (cnt != total)
		return (14);
	m_freem(hold);
	if (freecount() != total)
		return (14);
	/* 15: chain operations */
	m = m_get(M_DONTWAIT, MT_DATA);
	n = m_get(M_DONTWAIT, MT_DATA);
	if (m == 0 || n == 0)
		return (15);
	m->m_len = 10;
	n->m_len = 10;
	m->m_next = n;
	for (i = 0, p = mtod(m, char *); i < 10; i++)
		p[i] = i;
	for (i = 0, p = mtod(n, char *); i < 10; i++)
		p[i] = i + 10;
	c1 = m_copy(m, 5, 10);		/* bytes 5..14 */
	if (c1 == 0)
		return (15);
	m_adj(c1, 2);			/* now 7..14 */
	c1 = m_pullup(c1, 8);
	if (c1 == 0 || c1->m_len < 8)
		return (15);
	p = mtod(c1, char *);
	for (i = 0; i < 8; i++)
		if (p[i] != i + 7)
			return (15);
	m_freem(c1);
	m_freem(m);
	if (freecount() != total)
		return (15);
	return (0);
}

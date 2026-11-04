/* netprobe4 -- spl, in_cksum and the mbuf allocator at interrupt level.  The
 * checksum values were computed by a Python one-liner, independently. */
#include "param.h"
#include "mbuf.h"

extern	int in_cksum();

static int
masked()
{
	int s, i;

	s = splhigh();
	i = s;
	splx(s);
	return (i != 0);
}

static struct mbuf *
chain(data, lens, n)
	char *data;
	int *lens, n;
{
	struct mbuf *head, *m, *t;
	register int i, j;
	char *p;

	head = t = 0;
	for (i = 0; i < n; i++) {
		m = m_get(M_DONTWAIT, MT_DATA);
		m->m_len = lens[i];
		p = mtod(m, char *);
		for (j = 0; j < lens[i]; j++)
			*p++ = *data++;
		if (t)
			t->m_next = m;
		else
			head = m;
		t = m;
	}
	return (head);
}

static char ckrfc[] = { 0x00, 0x01, 0xf2, 0x03, 0xf4, 0xf5, 0xf6, 0xf7 };
static char ckseq[29];
static int  lens1[] = { 8 };
static int  lens29a[] = { 29 };
static int  lens29b[] = { 4, 7, 18 };
static int  lens29c[] = { 3, 0, 26 };

int
netprobe4()
{
	struct mbuf *m, *hold;
	int s, s2, i, drains;

	/* 21: splimp and splhigh mask and report, splnet does neither, splx
	 * restores from either start */
	if (masked())
		return (21);
	s = splimp();
	if (s != 0 || !masked())
		return (21);
	s2 = splhigh();
	if (s2 == 0)
		return (21);
	splx(s2);
	if (!masked())
		return (21);
	splx(s);
	if (masked())
		return (21);
	s = splnet();
	if (s != 0 || masked())
		return (21);
	splx(s);
	/* 22: one mbuf, against independent values */
	m = chain(ckrfc, lens1, 1);
	i = in_cksum(m, 8);
	m_freem(m);
	if ((u_short)i != 0x0d22)
		return (22);
	for (i = 0; i < 29; i++)
		ckseq[i] = i + 1;
	m = chain(ckseq, lens29a, 1);
	i = in_cksum(m, 29);
	m_freem(m);
	if ((u_short)i != 0x2d1e)
		return (22);
	/* 23: the same bytes across mbufs, an odd one in the middle */
	m = chain(ckseq, lens29b, 3);
	i = in_cksum(m, 29);
	m_freem(m);
	if ((u_short)i != 0x2d1e)
		return (23);
	/* ...and with an empty one */
	m = chain(ckseq, lens29c, 3);
	i = in_cksum(m, 29);
	m_freem(m);
	if ((u_short)i != 0x2d1e)
		return (23);
	/* ...and a len shorter than the chain */
	m = chain(ckrfc, lens1, 1);
	m->m_len = 8;
	i = in_cksum(m, 2);
	m_freem(m);
	if ((u_short)i != 0xfeff)
		return (23);
	/* 24: an empty pool at interrupt level fails without running the drains */
	hold = 0;
	while ((m = m_get(M_DONTWAIT, MT_DATA)) != 0) {
		m->m_next = hold;
		hold = m;
	}
	drains = mbstat.m_drain;
	s = splimp();
	m = m_get(M_DONTWAIT, MT_DATA);
	splx(s);
	if (m != 0 || mbstat.m_drain != drains) {
		m_freem(hold);
		return (24);
	}
	/* 25: at no mask it may drain, and still fails cleanly */
	m = m_get(M_DONTWAIT, MT_DATA);
	if (m != 0 || mbstat.m_drain != drains + 1) {
		m_freem(hold);
		return (25);
	}
	m_freem(hold);
	return (0);
}

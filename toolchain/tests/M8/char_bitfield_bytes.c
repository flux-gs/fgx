/* Char-typed bit-fields take BYTE units, as 2.11BSD's ccom lays them out
 * (usr/lib/ccom/c03.c, align()): netinet/ip.h's struct ip is 20 bytes on the
 * wire, with ip_hl and ip_v sharing its first byte and ip_tos its second. */
struct iph {
	unsigned char	hl:4,
			v:4;
	unsigned char	tos;
	short	len;
	unsigned short	id;
	short	off;
	unsigned char	ttl;
	unsigned char	p;
	unsigned short	sum;
	long	src, dst;
};
struct odd { char c; unsigned char lo:3, hi:5; };	/* a unit at an odd byte */
struct iph gh;

int main()
{
	struct iph lh;
	struct odd od;
	unsigned char *b = (unsigned char *)&lh;
	int bad = 0;

	if (sizeof(struct iph) != 20) bad |= 1;
	lh.tos = 0x5A;
	lh.hl = 5; lh.v = 4;
	if (b[0] != 0x45 || b[1] != 0x5A) bad |= 2;
	if (lh.hl != 5 || lh.v != 4 || lh.tos != 0x5A) bad |= 4;
	gh.hl = 6; gh.v = 4; gh.tos = 1;
	if (((unsigned char *)&gh)[0] != 0x46 || gh.tos != 1) bad |= 8;
	od.c = 0x11; od.lo = 5; od.hi = 17;
	if (sizeof(struct odd) != 2 || od.c != 0x11 ||
	    ((unsigned char *)&od)[1] != (17 << 3 | 5)) bad |= 16;
	return bad ? bad : 42;
}

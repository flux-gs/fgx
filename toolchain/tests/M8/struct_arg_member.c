/* A 4-byte struct passed by value: from a variable, through `.', through
 * `->' then `.', and one `->' hop in.  2.11BSD ntp prints peers as
 * ntoa(peer->src.sin_addr). */
struct in_addr { unsigned long s_addr; };
struct sockaddr_in { short sin_family; unsigned short sin_port; struct in_addr sin_addr; };
struct peer { int stratum; struct in_addr v; struct sockaddr_in src; };

int sum(a)
struct in_addr a;
{
	unsigned char *p = (unsigned char *)&a.s_addr;
	return p[0] + p[1] + p[2] + p[3];
}

int main()
{
	struct peer pr, *pp = &pr;
	struct in_addr v;
	int bad = 0;
	v.s_addr = 0x04030201L;			/* bytes 1,2,3,4: sum 10 */
	pr.src.sin_addr = v;
	pr.v = v;
	if (sum(v) != 10) bad |= 1;
	if (sum(pr.src.sin_addr) != 10) bad |= 2;
	if (sum(pp->src.sin_addr) != 10) bad |= 4;
	if (sum(pp->v) != 10) bad |= 8;
	return bad ? bad : 42;
}

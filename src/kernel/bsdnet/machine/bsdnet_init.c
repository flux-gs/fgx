/* bsdnet_init -- the C entered once, when the last network module has loaded
 * and every bank is linked.  2.11BSD's netstart() order: mbinit, then the
 * domains.  Returns 0, or the number of the first failed probe case; mod_init
 * logs which. */
extern int mbinit(), domaininit(), net_hookinit(), net_stack_paint();
extern void net_calloutinit();
#ifdef NETPROBE
extern int netprobe();
#endif

int
bsdnet_init()
{
	net_stack_paint();
	net_hookinit();		/* first: the initializers below may schedule */
	net_calloutinit();
	mbinit();
	domaininit();
#ifdef NETPROBE
	return (netprobe());
#else
	return (0);
#endif
}

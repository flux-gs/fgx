/* bsdnet_init -- the C entered once, when the last network module has loaded
 * and every bank is linked.  Returns 0, or the number of the first failed
 * probe case; mod_init logs which. */
#ifdef NETPROBE
extern int netprobe();
#endif

int
bsdnet_init()
{
#ifdef NETPROBE
	return (netprobe());
#else
	return (0);
#endif
}

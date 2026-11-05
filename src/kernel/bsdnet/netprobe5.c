/* netprobe5 -- netintr at the drain.  The answer arrives after the probe has
 * returned, so the hook logs it and the test reads the log. */
#include "param.h"
#include "../net/netisr.h"
#if NETPROBE == 3
extern void sleep();
#endif

extern int (*np_hook)();
extern int np_entries;
extern int kc_printstr();
extern unsigned net_stack_bot();

static int np_passes;
static int np_oncedone;

#if NETPROBE == 2
static int
deep(n)
	int n;
{
	char b[200];

	b[0] = n;
	return (deep(n + 1) + b[0]);
}
#endif

static int
hook(bits)
	int bits;
{
	unsigned here;

	np_passes++;
	if (!np_oncedone) {
		np_oncedone = 1;
		/* 32: on netintr's own stack */
		here = (unsigned)(long)&here;
		if (here < net_stack_bot() || here >= net_stack_bot() + 1024)
			kc_printstr("bsdnet: BROKEN 32");
		else
			kc_printstr("bsdnet: netintr on its stack");
#if NETPROBE == 2
		/* 33: halts through _fcc_stkoflow, which kernel.netprobe = 2 reads */
		deep(0);
#endif
#if NETPROBE == 3
		/* 34: panics, which kernel.netprobe = 3 reads */
		sleep((caddr_t)&np_passes, 0);
#endif
		schednetisr(NETISR_NS);	/* no handler: only the loop can see it */
		kc_printstr("bsdnet: netintr first pass");
	} else if (np_passes == 2 && np_entries == 1)
		kc_printstr("bsdnet: netintr second pass, same entry");
	return (0);
}

int
netprobe5()
{
	np_hook = hook;
	schednetisr(NETISR_NS);
	/* 31: not synchronous */
	if (np_passes != 0)
		return (31);
	return (0);
}

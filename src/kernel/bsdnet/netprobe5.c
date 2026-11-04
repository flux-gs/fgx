/* netprobe5 -- netintr at the drain.  The answer arrives after the probe has
 * returned, so the hook logs it and the test reads the log. */
#include "param.h"
#include "../net/netisr.h"

extern int (*np_hook)();
extern int np_entries;
extern int kc_printstr();

static int np_passes;
static int np_oncedone;

static int
hook(bits)
	int bits;
{
	np_passes++;
	if (!np_oncedone) {
		np_oncedone = 1;
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

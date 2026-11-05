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
extern int kc_ticks();
extern void np6_sample();
extern int netprobe6();
extern void timeout(), untimeout();
extern int np_slowruns;	/* machine/net_callout.c: pfslowtimo's runs */

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

/* 35-38.  The expiries land after the probe returns, so the hook samples them. */
static long np_now, np_t0;
static long np_fire35;
static int np_n35, np_n36, np_done;
static int np_order[4], np_norder;

static int
f35(arg, late)
	caddr_t arg;
	int late;
{
	kc_ticks(&np_fire35);
	np_n35++;
	return (0);
}

static int
f36(arg, late)
	caddr_t arg;
	int late;
{
	np_n36++;
	return (0);
}

static int
f37(arg, late)
	caddr_t arg;
	int late;
{
	if (np_norder < 4)
		np_order[np_norder++] = (int)(long)arg;
	return (0);
}

static int
callouts_verdict()
{
	long d;

	if (np_n35 != 1)
		return (35);
	d = np_fire35 - np_t0;
	if (d < 30L || d > 38L)
		return (35);
	if (np_n36 != 0)
		return (36);
	if (np_norder != 3 || np_order[0] != 1 || np_order[1] != 2 ||
	    np_order[2] != 3)
		return (37);
	if (np_slowruns == 0)
		return (38);
	return (0);
}

static void
callouts_sample()
{
	if (np_done)
		return;
	kc_ticks(&np_now);
	if (np_now - np_t0 < 90L)
		return;
	np_done = 1;
	switch (callouts_verdict()) {
	case 0:
		kc_printstr("bsdnet: callouts ok");
		break;
	case 35:
		kc_printstr("bsdnet: BROKEN 35");
		break;
	case 36:
		kc_printstr("bsdnet: BROKEN 36");
		break;
	case 37:
		kc_printstr("bsdnet: BROKEN 37");
		break;
	default:
		kc_printstr("bsdnet: BROKEN 38");
		break;
	}
}

static int
hook(bits)
	int bits;
{
	unsigned here;

	np_passes++;
	callouts_sample();
	np6_sample();
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
	kc_ticks(&np_t0);
	timeout(f35, (caddr_t)0, 30);
	if (np_n35 != 0)	/* 35: not at once */
		return (35);
	timeout(f36, (caddr_t)0, 10);
	untimeout(f36, (caddr_t)0);
	timeout(f37, (caddr_t)1L, 20);	/* 37: armed out of order */
	timeout(f37, (caddr_t)3L, 40);
	timeout(f37, (caddr_t)2L, 30);
	return (netprobe6());
	return (0);
}

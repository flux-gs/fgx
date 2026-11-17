/* s2_stubs.c -- what a later phase replaces. */
extern void panic();

/* sbselqueue's test of a selecting process, against FGX's selwait channel
 * (machine/bn_sys.c selwakeup). */
int selwait;

/* S4: a socket's process group.  Reached only through SIOCSPGRP and FIOASYNC,
 * which the kernel's _IoOp_Socket refuses with ENOTTY. */
void
gsignal(pgrp, sig)
	int pgrp, sig;
{
	panic("gsignal: no process groups on a socket yet");
}

char *
netpfind(pid)
	int pid;
{
	panic("netpfind: no process groups on a socket yet");
	return (0);
}

/* S5: the sysctl names. */
int
sysctl_int(oldp, oldlenp, newp, newlen, valp)
	char *oldp, *newp;
	int *oldlenp, *valp;
	int newlen;
{
	panic("sysctl_int: no sysctl yet");
	return (0);
}

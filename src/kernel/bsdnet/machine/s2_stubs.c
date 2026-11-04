/* s2_stubs.c -- what a later phase replaces.  Nothing network-facing runs yet. */
extern void panic();

/* ponytail: S2's callout facility.  domaininit arms pfslowtimo and pffasttimo
 * through this, so at this phase a timer simply never fires. */
void
timeout(fun, arg, t)
	int (*fun)();
	char *arg;
	int t;
{
}

void
untimeout(fun, arg)
	int (*fun)();
	char *arg;
{
}

/* S3: a task behind a socket. */
int selwait;

int
uiomove(cp, n, uio)
	char *cp;
	int n;
	char *uio;
{
	panic("uiomove: no socket calls yet");
	return (0);
}

void
gsignal(pgrp, sig)
	int pgrp, sig;
{
	panic("gsignal: no socket calls yet");
}

char *
netpfind(pid)
	int pid;
{
	panic("netpfind: no socket calls yet");
	return (0);
}

void
netpsignal(p, sig)
	char *p;
	int sig;
{
	panic("netpsignal: no socket calls yet");
}

void
selwakeup(p, coll)
	char *p;
	long coll;
{
	panic("selwakeup: no socket calls yet");
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

int
copyout(from, to, n)
	char *from, *to;
	int n;
{
	panic("copyout: no socket calls yet");
	return (0);
}

/* Task 6 replaces this. */
void setsoftnet() { }

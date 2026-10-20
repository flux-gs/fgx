/* c34_eintr.c — syscall-return preservation across signal delivery
 * (2026-07-06 quick-win; the "EINTR wart" c29 documented).  The dispatcher
 * hands _sig_tramp the interrupted syscall's result (X=A, Y=Y-return,
 * C=success) and the trampoline must restore all three, so kill(2)'s own
 * 0-with-C=1 return survives its exit-time delivery.  The old trampoline
 * clobbered them: A came back as handler garbage and a clobbered C could
 * flip the shim into its errno tail (spurious -1 + errno). */
extern int signal(int sig, void (*h)(int));
extern int kill(int pid, int sig);
extern int getpid(void);
extern void c34_handler(int sig);    /* pinned in a DIFFERENT code bank */
extern int c34_count;                /* defined in the handler's TU */
extern int errno;

int c34_check(void)
{
	int r;

	if (signal(2, c34_handler) == -1) return 0;   /* SIGINT = 2 */
	errno = 0;
	r = kill(getpid(), 2);       /* delivered at THIS syscall's exit */
	if (c34_count != 1) return 0;                 /* handler really ran */
	if (errno != 0) return 0;    /* C-clobber would take the errno tail */
	return r == 0;               /* kill's own return survived delivery */
}

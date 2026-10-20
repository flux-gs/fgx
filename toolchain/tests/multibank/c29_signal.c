/* c29_signal.c — SHIM+ADAPTER construct (2026-07-05 audit): REAL signal(3)
 * delivery into an fcc C handler in a DIFFERENT code bank.  Exercises the
 * whole chain: c_signal records the handler far ptr + registers libc's
 * signal trampoline with the kernel; kill(2) posts SIGINT to self; the
 * kernel delivers at that syscall's exit via register+RTL into the
 * trampoline, which re-shapes it into a normal fcc far call to c29_handler
 * (cross-bank).  Before the audit both c_signal and c_kill were silent
 * no-op success stubs, so the install vanished and the flag stayed 0.
 *
 * NOTE: kill()'s return went unchecked here while the trampoline clobbered
 * the interrupted syscall's A/C (the old "EINTR wart").  FIXED 2026-07-06:
 * _sig_tramp now saves/restores P/X/Y and re-materialises A — c34 is the
 * construct that pins the preserved return. */
extern int signal(int sig, void (*h)(int));
extern int kill(int pid, int sig);
extern int getpid(void);
extern void c29_handler(int sig);    /* pinned in a DIFFERENT code bank */
extern int c29_flag;                 /* defined in the handler's TU */

int c29_check(void)
{
	if (signal(2, c29_handler) == -1) return 0;   /* SIGINT = 2 */
	kill(getpid(), 2);           /* posts; delivered at this syscall's exit */
	return c29_flag == (0x2900 + 2);
}

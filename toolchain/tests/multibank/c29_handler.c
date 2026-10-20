/* c29_handler.c — the fcc C signal handler, pinned in a DIFFERENT code bank
 * than seg0's _sig_tramp (construct 29).  Entered as a normal fcc far call
 * (3-byte frame + int arg on the stack) courtesy of the trampoline. */
int c29_flag = 0;

void c29_handler(int sig)
{
	c29_flag = 0x2900 + sig;
}

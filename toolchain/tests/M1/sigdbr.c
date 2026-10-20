/* sigdbr.c - P3-3 3.2c: main-oracle regression for the _SIG_DATA_DP clobber
 * (3.1a's 16-bit `STZ _fcc_ssp+2` zeroed $BF -- the signal DATA-bank stash
 * _libc_start publishes for the trampoline (libc_start.s, _LS_DATA_DP) --
 * on EVERY function entry; fixed 3.2b by relocating the stash to $B8).
 * The handler stores to a DATA-SEGMENT global, which is DBR-relative: under
 * the bug _sig_tramp pulls bank 0 into DBR, the store misses the global, and
 * sig_flag stays 0 -> exit 3 (or a crash -- bank 0 holds this task's own DP
 * and stack), never 42.  RED-PROVEN 3.2c: with _SIG_DATA_DP patched back to
 * $BF this fixture fails.  churn() runs real fcc prologues between install
 * and delivery, pinning the "any fn entry wipes the stash" class; the
 * multibank flavor of this gate is sweep construct 29 (c29_signal). */
extern int signal(int sig, void (*h)(int));
extern int kill(int pid, int sig);
extern int getpid(void);

int sig_flag = 0;

void sig_handler(int sig)
{
	sig_flag = 0x4200 + sig;	/* DBR-relative data-seg store */
}

int churn(int n)
{
	int a;				/* real frame: prologue runs */

	a = n + 1;
	return a;
}

int main(void)
{
	int r;

	if (signal(2, sig_handler) == -1)	/* SIGINT = 2 */
		return 1;
	r = churn(1) + churn(2);	/* fn entries AFTER install */
	if (r != 5)
		return 2;
	kill(getpid(), 2);		/* delivered at this syscall's exit */
	if (sig_flag != 0x4202)
		return 3;		/* handler ran with the wrong DBR */
	return 42;
}

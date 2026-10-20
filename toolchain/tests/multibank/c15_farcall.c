/* c15_farcall.c — construct 15: a direct call to c15_callee(), whose TU is
 * pinned in a DIFFERENT code bank (bankmap 'callees' + the gen_sweep_link lint).
 * The FGX2_FARCALL must return to the right bank AND leave DBR = data seg.
 * Mole: farcall2bank return bank + the DBR-restore contract. */
extern int c15_callee(void);        /* separate TU, different code bank */
extern unsigned char c15_g[4];      /* its data-bank global (tag) */

int c15_check(void)
{
	int v = c15_callee();               /* cross-bank call + return */
	return v == (0x3F + 0x9F)           /* callee read its own global correctly */
	    && c15_g[0] == 0x3F && c15_g[3] == 0x9F;  /* 2nd path: DBR restored after return */
}

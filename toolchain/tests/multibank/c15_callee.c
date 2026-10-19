/* c15_callee.c — an extern-linkage function whose TU is pinned in a HIGH code
 * bank (bankmap).  Two uses:
 *   - preflight (driver.c): mb_bankof(&c15_callee) must differ from the data
 *     bank, proving the binary is genuinely multi-bank.
 *   - construct 15 (Task 2): a real cross-bank call from c15_farcall.c.
 * Separate TU (not a static in the caller) so placement can pin it to a
 * different segment — a static callee would land in its caller's segment and
 * the "cross-bank" call would silently be intra-bank (false green). */
unsigned char c15_g[4] = { 0x3F, 0x5F, 0x7F, 0x9F };

int c15_callee(void) { return c15_g[0] + c15_g[3]; }   /* 0x3F + 0x9F = 0xDE */

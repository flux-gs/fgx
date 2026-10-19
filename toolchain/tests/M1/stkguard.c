/* stkguard.c - P3-3 3.2b F9 coverage.  Unbounded recursion overflows ANY stack
 * (sized or not), so the prologue overflow guard MUST trap the task (exit 134 =
 * _fcc_stkoflow) before it scribbles past the stack pages.  Recursion is a
 * guard trigger (STKGUARD=1) AND sizing-independent, so this stays a trap
 * regardless of stack_frames / floor tuning -- a robust proof that the
 * "silent overrun" class is now caught, not merely sized away.  `pad` keeps
 * each frame non-trivial so the overflow arrives promptly; the `+ pad[0]` after
 * the call keeps it a real (non-tail) recursion. */
int sink;

int recurse(int n)
{
	char pad[32];

	pad[0] = (char)n;
	sink = sink + pad[0];
	return recurse(n + 1) + pad[0];		/* no base case: guard traps first */
}

int main(void)
{
	return recurse(0);			/* never returns 42 */
}

/* stkfloor.c - P3-3 3.2c: gates the KERNEL floor seed (FGX process.s seeds
 * _fcc_stkfloor = TCB_StackBase + FCC_STK_FLOOR_MARGIN at spawn).  A bounded
 * recursion that crosses the seeded floor without wrapping S past 0, so the
 * guard's borrow (BCC) arm never fires -- the ONLY way this exits 134 is the
 * `CMP _fcc_stkfloor' arm catching S below a genuinely seeded floor.  An
 * unseeded floor (0) lets rec() finish and main return 42 -> deterministic red.
 * Complements stkguard.c (unbounded recursion), which proves the guard
 * MECHANISM but would still trap via the wrap arm even with a zero floor.
 *
 * LAUNCH GEOMETRY.  Task_AllocStack allocates N+1 pages, where N = header
 * hint + ceil(T/256) and the +1 is the GUARD page.  TCB_StackBase is the base
 * of the WHOLE region (guard page included) and StackSize = (N+1)<<8, so
 * floor = StackBase + MARGIN(128) sits INSIDE the guard page.  With T the
 * staged argv/envp frame:
 *     usable-above-floor = StackSize - T - 128
 * The descent must EXCEED usable to cross the floor (exit 134), and stay under
 * usable+128 so the UNSEEDED (red) case stays above StackBase -- no cross-task
 * scribble, clean 42.
 *
 * WHY RECURSION, AND A DEPTH IN DATA.  The fixture links as a static program
 * does, so the stack model measures it: the hint covers every frame the call
 * graph shows, and a single big frame would be reserved for and never cross
 * the floor.  A recursion bounded by DATA is the one thing the model cannot
 * size -- it charges the deepest cycle member CYCLE_TURNS extra turns
 * (stack_measure.py) -- so the hint is the same whatever `depth' holds, and
 * the descent can be tuned without the reservation moving.  rec() is
 * self-recursive, which gives it STKGUARD=1, and each level is 23 B (16 B
 * frame, saved frame pointer 2, return address 3, argument 2) -- under
 * MARGIN, so the level that crosses the floor is still above StackBase.
 *
 * Measured by bisection, 2026-10-06: depth 66, 67 -> 42 (no trap); 68, 69, 70,
 * 75, 78 -> 134.  The window is depth [68, 72] (five 23 B levels within
 * MARGIN); 70 sits mid-window.
 *
 * TO RE-DERIVE after any change to the launch path, the guard page, argv/envp,
 * MARGIN, CYCLE_TURNS or rec()'s frame: bisect `depth' with `run_runtime.py
 * --names stkfloor --use-fcc toolchain/fcc' (default mode runs the
 * .expected.bin run.sh built from the golden), find the first depth that
 * exits 134, then pick the middle of the levels that fit in MARGIN above it. */
int sink;
int depth = 70;

void rec(int n)
{
	int pad[8];

	pad[0] = n;
	pad[7] = n;
	sink = sink + pad[0] + pad[7];
	if (n > 1)
		rec(n - 1);
}

int main(void)
{
	rec(depth);			/* traps at the seeded floor: exit 134 */
	return 42;			/* reached only if the seed is broken */
}

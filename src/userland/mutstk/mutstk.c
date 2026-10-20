/* mutstk - unbounded MUTUAL recursion through small frames, with a syscall in
 * the cycle.  The fixture for bank-0 stack campaign increment 0.2.
 *
 * FGX-Provenance: none
 *
 * fcc's prologue overflow guard (STKGUARD) arms on exactly three things: an
 * indirect call, SELF-recursion, or a frame >= 128 bytes.  Two small functions
 * calling each other are none of those, so nothing is emitted, and the pair
 * descends past TCB_StackBase into whatever the arena put underneath -- another
 * task's live stack.  That is the silent-cross-task-corruption class: it
 * presents as SOMEONE ELSE's failure, and on this project that has meant bugs
 * surviving until the test oracle itself was repaired.  tcsh has a 117-member
 * recursion SCC, so this is not a hypothetical shape.
 *
 * ping() and pong() are deliberately kept under the guard's arming threshold
 * and deliberately not self-recursive.  Verify with:
 *
 *     grep _STKGUARD build/mutstk.s        -> both must be 0
 *
 * getpid() in the cycle is the point: a runaway recursion cannot do anything
 * useful without a syscall, so the dispatcher is the one place it must pass
 * through.  Increment 0.2 checks the user SP against the task's floor there and
 * converts the call to exit(134).
 *
 * Expected: the kernel kills this with "stack overflow (syscall floor): killed
 * pid $NN" and the machine is still healthy afterwards.  Reaching the printf at
 * the bottom would mean the recursion terminated, which it cannot.
 */
#include <stdio.h>

int depth;

int pong();

int
ping()
{
	int	a;

	a = depth++;
	getpid();
	return a + pong();
}

int
pong()
{
	int	b;

	b = depth++;
	getpid();
	return b + ping();
}

/* The OTHER detector.  Self-recursion with a 200-byte frame arms STKGUARD, and
 * there is no syscall anywhere in the cycle -- so the dispatcher floor check
 * (0.2) never sees this task and fcc's prologue guard is the only thing that
 * can stop it.  Worth its own mode: as of 0.2 the floor check fires FIRST for
 * anything that syscalls (measured on srcdepth_loud: 8094/8192 rather than
 * 8120/8192), which quietly took the prologue-guard path out of every test that
 * used to cover it.  A guard nothing exercises is a guard nobody has seen work,
 * and increment 3.1 has to rewrite this one to be resumable.
 */
int
sink(n)
	int	n;
{
	char	pad[200];

	pad[0] = (char)n;
	pad[199] = (char)n;
	return pad[0] + sink(n + 1);
}

int
main(argc, argv)
	int	argc;
	char	**argv;
{
	if (argc > 1 && argv[1][0] == 'd') {
		printf("MUTSTK DEEP\n");
		sink(0);
		printf("MUTSTK RETURNED -- unreachable\n");
		return 0;
	}
	printf("MUTSTK START\n");
	ping();
	printf("MUTSTK RETURNED %d -- unreachable\n", depth);
	return 0;
}

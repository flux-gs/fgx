/* rand/srand + random/srandom (one shared 32-bit LCG in the C pile) —
 * pin the exact sequences so the generator is deterministic across
 * releases (games replay identically for a given seed).  Constants
 * host-computed from seed*1103515245+12345 mod 2^32:
 *   srand(1):   rand() -> 16838, 5758, 10113
 *   srandom(7): random() -> 1282156110, 712267922
 * random() is 31-bit (two steps, hi15<<16 | lo16); rand() is 15-bit. */
#include <stdlib.h>

int
main()
{
	long g;

	srand(1);
	if (rand() != 16838)
		return 1;
	if (rand() != 5758)
		return 2;
	if (rand() != 10113)
		return 3;

	srandom(7);
	g = random();
	if (g != 1282156110L)
		return 4;
	g = random();
	if (g != 712267922L)
		return 5;

	/* range use: worm's rnd() shape — abs((rand()>>5)+(rand()>>5)) % n */
	srand(42);
	if (abs((rand() >> 5) + (rand() >> 5)) % 80 >= 80)
		return 6;
	if (abs(-7) != 7 || abs(7) != 7)
		return 7;
	return 42;
}

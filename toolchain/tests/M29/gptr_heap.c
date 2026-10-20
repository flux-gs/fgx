/* gptr_heap.c — reproduce ed's corrupt-line-handle bug in isolation.
 *
 * ed stores line handles in a malloc'd int[] addressed by GLOBAL int* (zero/
 * dot/dol/addr1/addr2).  Instrumentation showed the handles store correctly
 * (2/6/10) but a later `getline(*a1++)` read returns garbage (675, 1536=6<<8),
 * pointing at a heap int* deref reading the wrong offset/bank when the pointer
 * is a global.  This mimics that exactly: store via the append shape
 * (`a1=++dol; while(a1>rdot) *--a2=*--a1; *rdot=tl`), then read via the 1,3p
 * shape (`a1=addr1; v=*a1++`).  Returns 42 iff the handles round-trip;
 * a failure returns the first wrong value (low byte) so the garbage is visible
 * in the exit code.  clang returns 42.
 */
#ifdef __FGX__
/* malloc takes the FULL 32-bit size_t on FGX: requests past one bank of break
 * go to a dedicated MM block, so malloc(80000L) is real.  It therefore CANNOT
 * be declared K&R empty-paren here -- `char *malloc();` makes the caller push a
 * 2-byte int for a 4-byte parameter, the callee reads a garbage high word, and
 * malloc returns NULL.  That is the whole of issue #10: this fixture exercises
 * ed's heap-pointer arithmetic, and it was failing before reaching any of it.
 * The K&R-unspecified-args coverage lives in fixtures whose callee arguments
 * are all int-width; for a 32-bit size_t the K&R spelling is not "unspecified",
 * it is wrong.  Same wording as heap_intptr.c and realloc_grow.c, which hit
 * this first. */
char *malloc(unsigned long);
#else
#include <stdlib.h>
#endif

int *zero, *dot, *dol, *addr1, *addr2;

/* ed's append() handle-store shape. */
store(tl)
{
	register int *a1, *a2, *rdot;

	a1 = ++dol;
	a2 = a1 + 1;
	rdot = ++dot;
	while (a1 > rdot)
		*--a2 = *--a1;
	*rdot = tl;
}

/* ed's address() pointer build: a1 = zero; a1 += n  (compound += on int*). */
int *
parse(n)
{
	register int *a1;

	a1 = zero;
	a1 += n;
	if (a1 < zero || a1 > dol)        /* ed's bounds check (heap ptr compare) */
		return 0;
	return a1;
}

/* getline-like: receives the handle value as an arg. */
int
consume(h)
{
	return h;
}

int
main(void)
{
	register int *a1;
	register int sum;

	zero = (int *)malloc(64);
	if (zero == 0) return 9;
	dot = dol = zero;

	store(2);                 /* zero[1] = 2  */
	store(6);                 /* zero[2] = 6  */
	store(10);                /* zero[3] = 10 */

	addr1 = parse(1);
	addr2 = parse(3);
	if (addr1 == 0 || addr2 == 0) return 8;

	/* ed's 1,3p read shape: do { consume(*a1++) } while (a1 <= addr2) */
	sum = 0;
	a1 = addr1;
	do {
		sum += consume(*a1++);
	} while (a1 <= addr2);

	if (sum != 18) return sum & 0xFF;   /* 2+6+10; garbage -> visible code */
	return 42;
}

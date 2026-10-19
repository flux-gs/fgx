/* memsetbig.c -- memset(3) and bzero(3) must cover the WHOLE 16-bit count.
 *
 * The word loop inside memset indexes `[dp],Y' with Y walking down to zero and
 * terminates on `BPL', so it ends on Y's SIGN.  That is correct for any count
 * whose halved-and-doubled form leaves bit 15 clear, and it silently does
 * NOTHING for 32770 or more: Y starts negative and the first BPL falls
 * through.  No fault, no short fill, no diagnostic -- the buffer is simply
 * untouched, and every caller of a large zero-fill believes otherwise.
 *
 * fsck(8) is the caller that found it.  2.11BSD's fsck bzeroes its whole map
 * arena in one call, and on a PDP-11 bzero is assembly that takes the count as
 * an unsigned word, so upstream has no such limit and FGX must not either.
 *
 * THE BUFFER IS POISONED FIRST, which is the whole discriminating trick: a
 * fresh heap block can read as zero already, so "memset did nothing" and
 * "memset worked" are the same picture unless the bytes started as something
 * else.  $A5 is the poison for the reason the bank-0 campaign uses it -- it is
 * distinctive in a dump and it is not zero.
 *
 * THE GUARD BYTES ARE THE OTHER HALF.  A split implementation can overrun as
 * easily as a signed one can under-run, so a byte before and a byte after the
 * region must survive untouched.
 *
 * Exit 42 = pass; every other code identifies the property that failed.
 */
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#define BIG     40000u          /* past the sign bit, under the 16-bit ceiling */
#define EDGE    0x7FFEu         /* the split threshold itself */

static int check(char *p, unsigned n, char want)
{
    unsigned i;

    for (i = 0; i < n; i++)
        if (p[i] != want)
            return (0);
    return (1);
}

static void poison(char *p, unsigned n)
{
    unsigned i;

    for (i = 0; i < n; i++)
        p[i] = (char)0xA5;
}

int main()
{
    char *base;
    char *p;

    /* One byte of guard on each side of the region under test. */
    base = (char *)malloc((unsigned long)BIG + 2);
    if (base == (char *)0)
        return (43);
    p = base + 1;

    /* 1. A count past the sign bit must zero every byte. */
    poison(base, BIG + 2);
    memset(p, 0, BIG);
    if (!check(p, BIG, (char)0))
        return (44);
    if (base[0] != (char)0xA5 || base[BIG + 1] != (char)0xA5)
        return (45);

    /* 2. And must fill with a non-zero byte just as completely -- a memset
     *    that reached the bytes but built its fill word wrong passes 1. */
    poison(base, BIG + 2);
    memset(p, 0x5C, BIG);
    if (!check(p, BIG, (char)0x5C))
        return (46);
    if (base[0] != (char)0xA5 || base[BIG + 1] != (char)0xA5)
        return (47);

    /* 3. The threshold itself, and one either side of it, because a split is
     *    an off-by-one waiting to happen. */
    poison(base, BIG + 2);
    memset(p, 0, EDGE);
    if (!check(p, EDGE, (char)0) || p[EDGE] != (char)0xA5)
        return (48);

    poison(base, BIG + 2);
    memset(p, 0, EDGE + 1);
    if (!check(p, EDGE + 1, (char)0) || p[EDGE + 1] != (char)0xA5)
        return (49);

    poison(base, BIG + 2);
    memset(p, 0, EDGE + 2);
    if (!check(p, EDGE + 2, (char)0) || p[EDGE + 2] != (char)0xA5)
        return (50);

    /* 4. A zero count must touch nothing at all. */
    poison(base, BIG + 2);
    memset(p, 0, (unsigned)0);
    if (p[0] != (char)0xA5)
        return (51);

    /* 5. bzero is the BSD spelling fsck uses and carries the same count. */
    poison(base, BIG + 2);
    bzero(p, BIG);
    if (!check(p, BIG, (char)0))
        return (52);
    if (base[0] != (char)0xA5 || base[BIG + 1] != (char)0xA5)
        return (53);

    return (42);
}

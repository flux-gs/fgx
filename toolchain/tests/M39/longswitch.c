/* M39 (frotz port): switch on a LONG selector compares BOTH words.
 * frotz quetzal's 4-char chunk IDs 'CMem'/'UMem' share their low word
 * ('em'), so the old 16-bit-truncating switch died "duplicate case
 * value" at parse -- and a 16-bit compare chain would DISPATCH wrong.
 * The 0x0001656D probe is the mutation-killer: its low word matches
 * 'em' but its high word matches no case, so it must fall to default. */

#define MKID(a,b,c,d) ((long)(((long)(a)<<24) | ((long)(b)<<16) | \
                              ((long)(c)<<8)  |  (long)(d)))

static int pick(long id)
{
    switch (id) {
        case MKID('C','M','e','m'): return 1;
        case MKID('U','M','e','m'): return 2;
        case MKID('S','t','k','s'): return 4;
        case 5:                     return 8;
        case -2:                    return 16;  /* hi word 0xFFFF */
        default:                    return 32;
    }
}

int main(void)
{
    long m2 = -2;
    long probe = 0x0001656DL;               /* low == 'em', hi matches none */

    if (pick(MKID('C','M','e','m')) != 1)  return 1;
    if (pick(MKID('U','M','e','m')) != 2)  return 2;
    if (pick(MKID('S','t','k','s')) != 4)  return 3;
    if (pick(5)                     != 8)  return 4;
    if (pick(m2)                    != 16) return 5;
    if (pick(MKID('A','N','N','O')) != 32) return 6;
    if (pick(probe)                 != 32) return 7;
    return 42;
}

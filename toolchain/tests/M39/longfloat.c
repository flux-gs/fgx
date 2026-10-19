/* M39 (frotz port): LONG op FLOAT promotes the long at its full width
 * (_fcc_ltof).  The old int-only promotion arm popped ONE word of the
 * two-word pushed long -- the high word stayed on the hardware stack
 * forever (stack_check "epilogue teardown at nonzero depth", tripped by
 * frotz dumb_input's `(time(0) - start_time) * 10 * speed`) -- and itof
 * read the low half as the whole value, so any long past 16 bits
 * scaled garbage.  0x30000 * 0.5 keeps a live high word on both sides
 * of the multiply. */

static float half = 0.5;

int main(void)
{
    long v;
    long w;
    float f;

    v = 0x30000;                /* 196608: high word 3, low word 0 */

    f = v * half;               /* long * float: the leaking arm */
    w = f;                      /* 98304 = 0x18000 */
    if ((w >> 15) != 3) return 1;
    if ((w & 0x7FFF) != 0) return 2;

    f = half * v;               /* float * long: the truncating arm */
    w = f;
    if ((w >> 15) != 3) return 3;

    return 42;
}

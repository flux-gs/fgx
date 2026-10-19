/* pp_adv2.c — T2-2 adversarial fixture 2: expansion mechanics.
 *   - NO accidental paste: `A B` from two macros must stay two tokens.
 *   - object-macro CHAINS resolve fully (A->B->C).
 *   - self-referential macro does not loop (rescan guard): `#define x x+1`
 *     leaves the inner `x` unexpanded.
 * Exit 42. */
#define ONE 1
#define TWO ONE + ONE
#define FOUR TWO + TWO

#define NEG -
#define ONE_NEG_ONE ONE NEG ONE          /* must be 1 - 1, not 1-1 pasted weirdness */

#define x_ 40
#define x x_ + 1                          /* self-ref guard: x_ resolves, x inside stays */

int main()
{
    int a = FOUR;                /* 4 */
    int b = ONE_NEG_ONE;         /* 0 */
    int c = x;                   /* 41 */
    return a + b + c - 3;        /* 4 + 0 + 41 - 3 = 42 */
}

/* goto + labels.
 *
 * Exercises:
 *   - forward goto (target appears after the goto in source)
 *   - backward goto (target appears before the goto — classic loop)
 *   - multiple gotos to the same label
 *   - label as a target inside an if branch
 *
 * Result: 42.
 */
int main()
{
    int i;
    int sum;
    sum = 0;
    i = 0;

    /* Forward goto: skip the dec_block on first entry. */
    goto inc_loop;

dec_block:
    sum = sum - 100;        /* never executed in this fixture */
    goto done;

inc_loop:
    if (i == 7) goto done;
    sum = sum + 6;          /* 7 iterations * 6 = 42 */
    i = i + 1;
    goto inc_loop;          /* backward goto */

done:
    return sum;
}

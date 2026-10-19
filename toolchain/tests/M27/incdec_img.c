/* fcc2 P1.4 regression: a value-DISCARDED ++/-- on a promoted int/char scalar
 * lowers to a single INC/DEC dp (2-byte DP read-modify-write) instead of the
 * load/CLC-ADC/store quartet.  Covers all 3 value-discarded statement sites:
 *   - for-step      (i++)
 *   - postfix-stmt  (i-- ; c++ ; c--)
 *   - prefix-stmt   (--i ; ++c)
 * on BOTH an int slot (INC + DEC) and a char slot (INC + DEC).  All of i/sum/c
 * are accessed >= the promotion threshold so they land in DP-IMG slots.  If
 * INC/DEC assembled as abs (EE/CE) instead of dp (E6/C6) it would hit the wrong
 * address (abs $00xx vs the task DP page) and the result would not be 42.
 * Values stay well within range so a host C reference (signed char) agrees.
 * Result must be 42. */
int main(void)
{
    int  i, sum;
    char c;

    sum = 0;
    for (i = 0; i < 10; i++)   /* for-step:     INC dp on int i              */
        sum = sum + 1;         /* sum = 10                                   */

    i = 8;
    i--;                       /* postfix-stmt: DEC dp on int  -> i = 7      */
    --i;                       /* prefix-stmt:  DEC dp on int  -> i = 6      */
    sum = sum + i;             /* sum = 16                                   */

    c = 10;
    c++;                       /* postfix-stmt: INC dp on char -> c = 11     */
    ++c;                       /* prefix-stmt:  INC dp on char -> c = 12     */
    c--;                       /* postfix-stmt: DEC dp on char -> c = 11     */
    sum = sum + c;             /* sum = 27                                   */

    return sum + 15;           /* 27 + 15 == 42                              */
}

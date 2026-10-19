/* Modulus operator (%).  Tests both binop form and %= compound form.
 *
 * 100 % 7  = 2
 *  -7 % 5  = -2  (C99 truncated; sign of dividend)
 *   7 % 5  =  2
 *   3 %= 7 -> 3
 *
 * Result: 42 (constructed below).
 */
int main()
{
    int x;
    int sum;

    sum = 0;
    sum = sum + (100 % 7);     /* 2 */
    sum = sum + (7 % 5);       /* 2 (=>4) */
    x = 40;
    x %= 12;                   /* 40 % 12 = 4 (=> ignored) */
    sum = sum + 38;            /* 42 */
    return sum;
}

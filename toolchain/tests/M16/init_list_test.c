/* M16 init-list: brace-initialised int-array globals.
 * Exercises:
 *   int arr[N] = {a, b, c};        explicit size, partial init (zero-fill)
 *   int arr[]  = {a, b, c, d};     sized-from-init
 *   int arr[]  = {-1, -2, 7};      unary-minus inside init list
 */

int g_explicit[5] = {7, 14, 21};       /* size 5, init 3 (rest zero) */
int g_inferred[] = {10, 20, 12};        /* size = 3 from init list */
int g_negs[] = {-1, -2, 8};             /* unary minus in init */

int main(void)
{
    /* g_explicit[0..4] = 7, 14, 21, 0, 0  → sum = 42 */
    int e_sum;
    int i_sum;
    int n_sum;
    e_sum = g_explicit[0] + g_explicit[1] + g_explicit[2]
          + g_explicit[3] + g_explicit[4];   /* 42 */
    i_sum = g_inferred[0] + g_inferred[1] + g_inferred[2]; /* 42 */
    n_sum = g_negs[2] - g_negs[0] - g_negs[1] - g_negs[2]; /* 8-(-1)-(-2)-8 = 3 */
    /* Pick e_sum as result; verify the others are consistent: */
    if (e_sum != 42) return 1;
    if (i_sum != 42) return 2;
    if (n_sum != 3)  return 3;
    return e_sum;   /* 42 */
}

/* sizeof_arrelem: parenthesized sizeof of an array element -- the array-count
 * idiom `sizeof(a) / sizeof(a[0])` (tcsh `sizeof(errorlist) /
 * sizeof(errorlist[0])`, tw.init's `sizeof(com_list[0])`).  fcc handled the
 * unparenthesized `sizeof a[0]` and `sizeof(var)`, but the parenthesized
 * `sizeof(a[0])` subscript died 'expected )'.  -> 42. */
int arr[10];

int
main()
{
    int n;
    n = sizeof(arr) / sizeof(arr[0]);   /* 20 / 2 == 10 */
    return n + 32;                      /* 10 + 32 == 42 */
}

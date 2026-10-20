/* array_param: C array-parameter decay.  `T p[]` / `T *p[]` and the abstract
 * `T []` / `T *[]` (tcsh sh.decls.h `Char *[]` prototypes) adjust to a pointer.
 * fcc handled plain named `int m[]` but rejected the starred and abstract
 * forms ("expected ',' or ')'"), blocking many tcsh TUs.  -> 42. */
extern void proto(char *[]);          /* abstract `char *[]` prototype */

static int
sum(int a[])                          /* `int []` -> int* */
{
    return a[0] + a[1];
}

static int
pick(char *v[], int i)                /* `char *[]` -> char** */
{
    return v[i][0] - '0';
}

int arr[2];
char *strs[2];

int
main()
{
    arr[0] = 20; arr[1] = 15;         /* sum -> 35 */
    strs[0] = "7"; strs[1] = "3";
    return sum(arr) + pick(strs, 0);  /* 35 + 7 == 42 */
}

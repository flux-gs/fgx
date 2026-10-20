/* strinit.c — correctness queue 6: the D-1 leftovers.
 *   - char s[] = "str"  (sizeless, size inferred = len+1)
 *   - char s[N] = "str" (sized; short string zero-fills the tail —
 *     this form previously fell into the SCALAR store arm and silently
 *     stored the string's ADDRESS into the array)
 *   - int a[] = {..} / char *p[] = {..} (sizeless brace lists,
 *     element count inferred by token prescan)
 * All standard C — clang cross-checks the exit.  Exit 42. */
char bx[2];

int main()
{
    char s[] = "world";          /* s[5] = NUL, size 6 */
    char t[8] = "hi";            /* t[2..7] zero-filled */
    int  a[] = {30, 2};
    char *p[] = {bx, bx};
    int r = 0;

    r += s[1] - 111;             /* 'o' - 'o' = 0 */
    r += s[5];                   /* NUL: +0 */
    r += (s[4] == 'd') ? 5 : 0;  /* +5 */

    r += t[0] - 104;             /* 'h' - 'h' = 0 */
    r += t[7];                   /* zero-fill: +0 */
    r += (t[1] == 'i') ? 3 : 0;  /* +3 */

    r += a[0] + a[1];            /* +32 */

    bx[0] = 2;
    r += p[1][0];                /* +2 */

    return r;                    /* 5+3+32+2 = 42 */
}

/* CU-1's ARRAY-OF-POINTERS twin: double-subscript STORES where the base is
 * `T *base[N]` rather than `T **base`.  `base[a]` is a pointer either way, so
 * `base[a][b] = c` is the same construct -- but the type is ARY(PTR(T)), not
 * PTR(PTR(T)), and the statement parser tested only the second shape.  The
 * first died "expected '='" on the second '[', an ARTIFICIAL reject: the READ
 * side (`c = base[a][b]`) already built exactly this chain.  Fixed 2026-08-02,
 * found writing bigfork's `p[i][0] = 'A'`.
 *
 * Covers a global ptr-array and a local one across plain '=', op=, postfix
 * ++/--, and a side-effecting index -- the matrix st2d.c runs for
 * pointer-to-pointer.  (No struct arm: a ptr-ARRAY struct MEMBER is a separate
 * unsupported shape, `gw.y[0] = r0` -- st2d.c's struct arm uses a `char **`
 * member, which works.)  Exits 42 iff all rows check (12 + 30). */
char r0[4];
char r1[4];
char *grows[2];

int
main()
{
    char *lrows[2];
    int i;
    int r = 0;

    grows[0] = r0;
    grows[1] = r1;

    i = 0;
    grows[0][i++] = 'A';        /* r0[0] = 'A'; i -> 1 */
    grows[0][i] = 'B';          /* r0[1] = 'B' */
    grows[1][0] = 7;
    grows[1][0] += 3;           /* r1[0] = 10 */
    grows[1][1] = 5;
    grows[1][1]++;              /* r1[1] = 6 */
    grows[1][2] = 9;
    grows[1][2]--;              /* r1[2] = 8 */

    lrows[0] = r0;
    lrows[1] = r1;
    lrows[0][2] = 'C';          /* r0[2] = 'C' */
    lrows[0][3] = 'D';          /* r0[3] = 'D' */
    lrows[1][3] = 4;
    lrows[1][3] |= 16;          /* r1[3] = 20 */
    lrows[1][0] -= 2;           /* r1[0] = 8 */
    lrows[1][1]++;              /* r1[1] = 7 */

    if (r0[0] == 'A' && r0[1] == 'B' && r0[2] == 'C' && r0[3] == 'D')
        r += 12;
    if (i == 1 && r1[0] == 8 && r1[1] == 7 && r1[2] == 8 && r1[3] == 20)
        r += 30;
    return r;
}

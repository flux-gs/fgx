/* CU-1: double-subscript STORES through pointer-to-pointer bases — a
 * global char **, a local char **, and a struct's char ** member reached
 * via p->y.  Mixes plain '=', op=, postfix ++/--, and a side-effecting
 * index ([i++]); every store must land where the desugared
 * *(yy[a] + b) = c form would put it.  Exits 42 iff all rows check
 * (12 + 30). */
struct w { char **y; };

char r0[4];
char r1[4];
char *rows[2];
char **gyy;
struct w gw;

int
main()
{
    char **ly;
    struct w *p;
    int i;
    int r = 0;

    rows[0] = r0;
    rows[1] = r1;
    gyy = rows;
    gw.y = rows;
    p = &gw;

    i = 0;
    gyy[0][i++] = 'A';          /* r0[0] = 'A'; i -> 1 */
    gyy[0][i] = 'B';            /* r0[1] = 'B' */
    gyy[1][0] = 7;
    gyy[1][0] += 3;             /* r1[0] = 10 */
    gyy[1][1] = 5;
    gyy[1][1]++;                /* r1[1] = 6 */
    gyy[1][2] = 9;
    gyy[1][2]--;                /* r1[2] = 8 */

    ly = rows;
    ly[0][2] = 'C';             /* r0[2] = 'C' */
    ly[1][3] = 4;
    ly[1][3] |= 16;             /* r1[3] = 20 */

    p->y[0][3] = 'D';           /* r0[3] = 'D' */
    p->y[1][0] -= 2;            /* r1[0] = 8 */
    p->y[1][1]++;               /* r1[1] = 7 */

    if (r0[0] == 'A' && r0[1] == 'B' && r0[2] == 'C' && r0[3] == 'D')
        r += 12;
    if (i == 1 && r1[0] == 8 && r1[1] == 7 && r1[2] == 8 && r1[3] == 20)
        r += 30;
    return r;
}

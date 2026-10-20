/* CU-1: ADDRESS-OF a double-subscript element — s = &yy[a][b] through a
 * global char ** and s = &p->y[a][b] through a char ** member must yield
 * yy[a] + b (pointee-scaled: 1 for char *, 2 for int * rows); stores
 * through the taken pointer are read back through the normal rvalue
 * path.  Exits 42 iff all three shapes land (14 + 14 + 14). */
struct w { char **y; };

char r0[4];
char r1[4];
char *rows[2];
char **gyy;
int i0[3];
int *irows[1];
int **gii;
struct w gw;

int
main()
{
    char *s;
    int *t;
    struct w *p;
    int a;
    int r = 0;

    rows[0] = r0;
    rows[1] = r1;
    gyy = rows;
    gw.y = rows;
    p = &gw;
    irows[0] = i0;
    gii = irows;
    a = 1;

    s = &gyy[a][2];             /* == r1 + 2 */
    *s = 'Q';
    if (gyy[1][2] == 'Q' && r1[2] == 'Q')
        r += 14;

    s = &p->y[0][a + 1];        /* == r0 + 2 */
    *s = 'Z';
    if (p->y[0][2] == 'Z' && r0[2] == 'Z')
        r += 14;

    t = &gii[0][2];             /* int rows scale by 2: == i0 + 2 */
    *t = 4242;
    if (gii[0][2] == 4242 && i0[2] == 4242 && i0[1] == 0)
        r += 14;

    return r;
}

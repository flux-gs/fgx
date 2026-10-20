/* M35/P3-3: local aggregates — a local struct (addressed via &local through a
 * callee) and a 2D local array.  These live in the frame; their field/element
 * addressing must follow the local through the flip.  (fcc has no struct
 * return-by-value — M8 — so the struct crosses the call boundary by pointer.)
 *
 * Portable C: clang returns 42. */
struct pt {
    int x, y;
};

void
mk(struct pt *p, int x, int y)         /* out-param: fcc has no struct-return */
{
    p->x = x;
    p->y = y;
}

int
psum(struct pt *p)
{
    return p->x + p->y;
}

int
main(void)
{
    struct pt a;
    int m[3][2];
    int i, j;

    mk(&a, 3, 4);                      /* &local struct passed to callee */
    if (a.x != 3 || a.y != 4) return 1;
    if (psum(&a) != 7)        return 2;

    for (i = 0; i < 3; i++)
        for (j = 0; j < 2; j++)
            m[i][j] = i * 10 + j;

    if (m[0][0] != 0)  return 3;
    if (m[2][1] != 21) return 4;
    if (m[1][0] != 10) return 5;

    return 42;
}

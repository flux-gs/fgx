/* An automatic struct takes the same nested initializer lists as a static
 * one, braced or elided (K&R A.8.7), and the members its list does not reach
 * are zero: "If there are fewer initializers in the list than members of the
 * structure, the trailing members are initialized with 0".  The stack is
 * dirtied first, so a member left unwritten reads as garbage, not as a lucky
 * zero.  Returns 42 when every check holds. */
struct cell { int pad; int v; };
struct tab  { int h; struct cell c[2]; };
struct rec  { int a; char name[4]; int t[2]; };

int dirty()
{
    int junk[24], i;

    for (i = 0; i < 24; i++)
        junk[i] = 0x5A5A;
    return junk[3];
}

int check()
{
    struct tab  x = { 1, { { 2, 3 }, { 4 } } };
    struct tab  y = { 1, 2, 3, { 4, 5 } };
    struct rec  r = { 9 };
    struct rec  q = { 9, "ab", { 6 } };
    int bad;

    bad = 0;
    if (x.h != 1 || x.c[0].v != 3 || x.c[1].pad != 4 || x.c[1].v != 0)
        bad++;
    if (y.c[0].pad != 2 || y.c[1].pad != 4 || y.c[1].v != 5)
        bad++;
    if (r.a != 9 || r.name[0] != 0 || r.name[3] != 0 || r.t[0] != 0 ||
        r.t[1] != 0)
        bad++;
    if (q.name[1] != 'b' || q.name[2] != 0 || q.t[0] != 6 || q.t[1] != 0)
        bad++;
    return bad;
}

int main()
{
    int bad;

    dirty();
    bad = check();
    return bad ? bad : 42;
}

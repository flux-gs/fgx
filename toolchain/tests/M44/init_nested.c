/* Nested braces inside a static struct's aggregate members.  K&R A.8.7: "If
 * an aggregate contains members of aggregate type, the initialization rules
 * apply recursively", and a member's initializer that "begins with a left
 * brace" initializes "the members of the subaggregate"; braces may also be
 * elided.  Each shape below must store the same bytes as its flat spelling.
 * Returns 42 when every check holds. */
struct cell { int pad; int v; };
struct tab  { int h; struct cell c[2]; };
struct grid { int h; int m[2][3]; char s[2][4]; };

/* fully braced: member, element, and struct */
struct tab  a = { 1, { { 2, 3 }, { 4, 5 } } };
/* outer level elided, inner braced: the '{' belongs to c[1] */
struct tab  b = { 1, 2, 3, { 4, 5 } };
/* short groups zero-fill their own aggregate: c[0].v and all of c[1] */
struct tab  c = { 1, { { 2 } } };
/* rows of a rank-2 member, a short row, and one string per char row */
struct grid g = { 7, { { 1, 2, 3 }, { 4 } }, { "ab", "cde" } };
/* an array of such structs, each element braced to the bottom */
struct tab  arr[2] = { { 1, { { 2, 3 }, { 4, 5 } } }, { 6, { { 7, 8 } } } };

int main()
{
    int bad;

    bad = 0;
    if (a.h != 1 || a.c[0].pad != 2 || a.c[0].v != 3 || a.c[1].pad != 4 ||
        a.c[1].v != 5)
        bad++;
    if (b.c[0].pad != 2 || b.c[0].v != 3 || b.c[1].pad != 4 || b.c[1].v != 5)
        bad++;
    if (c.h != 1 || c.c[0].pad != 2 || c.c[0].v != 0 || c.c[1].pad != 0 ||
        c.c[1].v != 0)
        bad++;
    if (g.m[0][2] != 3 || g.m[1][0] != 4 || g.m[1][1] != 0 || g.m[1][2] != 0)
        bad++;
    if (g.s[0][1] != 'b' || g.s[0][2] != 0 || g.s[1][2] != 'e' ||
        g.s[1][3] != 0)
        bad++;
    if (arr[0].c[1].v != 5 || arr[1].h != 6 || arr[1].c[0].v != 8 ||
        arr[1].c[1].pad != 0)
        bad++;
    return bad ? bad : 42;
}

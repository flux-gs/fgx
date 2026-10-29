/* A pointer field of a static struct initialized with the address of a
 * constant-subscripted array member: K&R A.7.19 "the unary & operator may be
 * applied to external or static objects, and to external and static arrays
 * subscripted with a constant expression".  Covers a subscript after a member
 * name and a member after a subscript.  Returns 42 when both pointers land. */
struct cell { int pad; int v; };
struct tab { int head; char s[8]; struct cell c[3]; };
struct tab g = { 0, "abcdefg", { 0, 1, 0, 2, 0, 40 } };

struct ref { char *p; int *q; };
struct ref r = { &g.s[2], &g.c[2].v };

int main()
{
    if (*r.p != 'c')
        return 1;
    return *r.q + (r.p - g.s);  /* 40 + 2 */
}

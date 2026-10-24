/* M37: a pointer local loaded into a register for one member access is not
 * loaded again for the next while nothing can have changed it (K&R A.7.3.3:
 * "E1->MOS is the same as (*E1).MOS").  Each case changes the pointer, or
 * its register, between two uses: an assignment, ++, a store through a
 * pointer to it, a call, a branch that joins, and an expression that loads
 * another pointer into the same register.  Returns 42. */
struct n { int a; int b; struct n *next; };

struct n x[4];
struct n *gp;

int same(struct n *p) { return p->a; }
void move(struct n **pp) { *pp = &x[3]; }

int main()
{
    struct n *p, *q, *r;
    struct n **pp;
    int i, s;

    for (i = 0; i < 4; i++) {
        x[i].a = i + 1; x[i].b = 10 * (i + 1);
        x[i].next = i < 3 ? &x[i + 1] : 0;
    }
    p = &x[0];
    s = p->a;  p = p->next;  s += p->a;            /* 1 + 2 */
    if (s != 3) return 1;
    p++;  if (p->a != 3 || p->b != 30) return 2;
    r = &x[0];  pp = &r;
    s = r->a;  *pp = &x[2];  s += r->a;            /* 1 + 3 */
    if (s != 4) return 3;
    q = &x[1];
    s = q->a;  move(&q);  s += q->a;               /* 2 + 4 */
    if (s != 6) return 4;
    p = &x[0];  q = &x[3];
    s = p->a + q->a + p->b;                        /* 1 + 4 + 10 */
    if (s != 15) return 5;
    s = 0;
    for (p = &x[0]; p; p = p->next)
        s += p->a > 2 ? p->b : p->a;               /* 1 + 2 + 30 + 40 */
    if (s != 73) return 6;
    p = &x[1];  gp = p;
    s = p->a;  gp->a = 9;  s += p->a;              /* 2 + 9: one struct */
    if (s != 11) return 7;
    p = &x[2];
    s = same(p) + p->b;                            /* 3 + 30 */
    if (s != 33) return 8;
    return 42;
}

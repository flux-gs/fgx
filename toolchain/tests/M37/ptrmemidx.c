/* Store to a '.'-member of an element indexed off an '->' POINTER member:
 * `t->ary[i].next = v` where ary is `struct he *` (joe scrn.c's hash build).
 * The per-shape arm indexed an ARRAY member; a POINTER member with a trailing
 * '.field' store fell through and died "expected '='".  Routed to the uniform
 * lvalue walker, type-gated so the array-member store (and `t->p[i] = v` with
 * no trailing dot) keep their existing handlers.  FGX-only oracle.  Value 42. */
struct he { int next; int loc; };
struct he pool[8];
struct scr { struct he *ary; };

int main(void)
{
    struct scr sv;
    struct scr *t = &sv;
    int i, r = 0;

    t->ary = pool;
    for (i = 0; i < 4; i++) {
        t->ary[i].next = i + 10;       /* ptr-member[i].field store */
        t->ary[i].loc  = i;
    }
    /* read them back, and a store whose RHS is the same shape */
    t->ary[2].next = t->ary[1].next;   /* = 11 */
    if (t->ary[0].next == 10) r += 10;
    if (t->ary[3].next == 13) r += 10;
    if (t->ary[2].next == 11) r += 10;
    if (t->ary[2].loc + t->ary[3].loc == 5) r += 12;  /* reads still fine */
    return r;                           /* 42 */
}

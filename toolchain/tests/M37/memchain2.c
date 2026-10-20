/* Two member-access chain gaps the joe port hit:
 *  - a '.'-member run PAST an indexed struct-array element reached through
 *    '->': `p->arr[i].a.b` (joe kbd.c `kmap->keys[x].value.submap`).  The
 *    arm read only one subfield and left the rest, dying "expected ';'".
 *  - a store whose target crosses TWO '->' before a '.': `p->q->r.s = v`
 *    (joe rc.c `bw->b->o.readonly = ...`), which had no statement arm and
 *    died "expected '='".
 * FGX-only oracle.  10 + 10 + 10 + 12 = 42. */
struct leaf { int b; int c; };
struct mid  { struct leaf a; int scal; };
struct top  { struct mid arr[4]; };

struct inner { int rdonly; };
struct outer { struct box { struct inner o; } *b; struct inner o; };

int main(void)
{
    struct top t;
    struct outer ov; struct box bx;
    int r = 0;

    t.arr[2].a.b = 7;                 /* dot run past indexed elem (dot base) */
    if (t.arr[2].a.b == 7) r += 10;

    { struct top *p = &t;
      p->arr[1].a.c = 9;              /* '->' arr[i].a.b store */
      if (p->arr[1].a.c == 9) r += 10;
      if (p->arr[1].a.c + p->arr[2].a.b == 16) r += 10; }  /* both as values */

    ov.b = &bx;
    ov.b->o.rdonly = ov.o.rdonly = 3; /* p->q->r.s = a.b = v (chained, 2 arrows) */
    if (ov.b->o.rdonly == 3 && ov.o.rdonly == 3) r += 12;

    return r;
}

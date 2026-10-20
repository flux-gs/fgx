/* Three more member/decl gaps from the joe port:
 *  - a POINTER-ARRAY member at the end of a MULTI-HOP arrow run, indexed:
 *    `bw->b->marks[c]` where marks is `P *marks[10]` (joe uedit.c).
 *  - a plain POINTER member reached by a dot past an arrow, indexed and read:
 *    `bw->o.rmsg[i]` where rmsg is `char *` (joe tw.c).
 *  - a `void *` local declaration inside a nested block (joe tw.c).
 * FGX-only oracle.  10 + 10 + 10 + 12 = 42. */
struct P { int v; };
struct b { struct P *marks[10]; };
struct o { char *rmsg; };
struct bw { struct b *b; struct o o; };

struct P pa, pb;
char msg[8];

int main(void)
{
    struct b bb; struct o oo; struct bw wv;
    struct bw *bw = &wv;
    int r = 0;

    pa.v = 4; pb.v = 6;
    bb.marks[2] = &pa; bb.marks[3] = &pb;
    wv.b = &bb;
    msg[0] = 'Z'; msg[1] = 0;
    oo.rmsg = msg;
    wv.o = oo;

    if (bw->b->marks[2]->v == 4) r += 10;      /* multi-hop ptr-array index */
    if (bw->o.rmsg[0] == 'Z') r += 10;          /* dot->ptr member, indexed read */
    { int y = bw->o.rmsg[0]; if (y == 'Z') r += 10; }

    if (bw->b->marks[3]) {                       /* nested block ... */
        void *op = bw->b->marks[3];              /* ... with a void* decl */
        struct P *pp = (struct P *)op;
        if (pp->v == 6) r += 12;
    }
    return r;
}

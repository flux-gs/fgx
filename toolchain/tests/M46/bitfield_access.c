/* A bit-field read and written through every way of reaching a member:
 * s.w.b, p->b, p->w.b, q->r->w.b, (p)->w.b, a[i].b, p->arr[i].b.  Each
 * write must change only its own bits of the containing word -- the
 * neighbors a and c keep their values -- and each read must give the
 * field, not the word.  2.11BSD's IP and TCP headers are bit-fields
 * (ip_hl:4, ip_v:4; th_off:4, th_x2:4), read and set through pointers.
 * Fields are unsigned here (K&R A.8.3: "whether an int field is treated as
 * signed is implementation-dependent").  Returns 42. */
struct bf { int a : 3; int b : 5; int c : 8; };
struct h { int z; struct bf w; struct bf arr[2]; } gh, *hp;
struct hh { int y; struct h *ph; } ghh, *hhp;

static int
ok(x)
	struct bf *x;
{
	return (x->a == 1 && x->c == 2);
}

int main()
{
	struct bf la[3], *bp;
	int i;

	hp = &gh; ghh.ph = &gh; hhp = &ghh; bp = &gh.w; i = 1;
	gh.w.a = 1; gh.w.c = 2;
	gh.arr[1].a = 1; gh.arr[1].c = 2;
	la[1].a = 1; la[1].c = 2;

	gh.w.b = 3;
	if (gh.w.b != 3 || !ok(&gh.w)) return (1);
	bp->b = 4;
	if (bp->b != 4 || gh.w.b != 4 || !ok(&gh.w)) return (2);
	hp->w.b = 9;
	if (hp->w.b != 9 || gh.w.b != 9 || !ok(&gh.w)) return (3);
	hhp->ph->w.b = 5;
	if (hhp->ph->w.b != 5 || gh.w.b != 5 || !ok(&gh.w)) return (4);
	(hp)->w.b = 6;
	if ((hp)->w.b != 6 || gh.w.b != 6 || !ok(&gh.w)) return (5);
	la[i].b = 7;
	if (la[i].b != 7 || la[1].b != 7 || !ok(&la[1])) return (6);
	hp->arr[i].b = 8;
	if (hp->arr[i].b != 8 || gh.arr[1].b != 8 || !ok(&gh.arr[1])) return (7);
	gh.w.b = 31 + 32;	/* only the low five bits are stored */
	if (gh.w.b != 31 || !ok(&gh.w)) return (8);
	return (42);
}

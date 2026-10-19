/* Address-of a struct-member-array element via '.' on a struct VALUE base —
 * cut.c's `&tmpblk.c[cb->start]` (tmpblk a BLK union, c a char[]).  addr =
 * &structvar + field offset (+ i*es for an indexed array member); no deref.
 * Const / variable / ptr->field index, int + char member arrays, a LOCAL struct
 * base, and bare `&structvar.field`.  -> 42. */
struct blk { int tag; char c[8]; int iv[4]; };
struct blk  gb;
struct pos  { int start; };
struct pos  gp;

int main(void)
{
	struct blk  lb;
	struct pos *cb;
	char       *q;
	int        *r;
	int        *tp;

	gb.c[2] = 'Z';
	gb.iv[3] = 7;
	gp.start = 2; cb = &gp;
	lb.c[1] = 'L';

	q = &gb.c[2];          if (q[0] != 'Z') return 1;   /* const index, global   */
	q = &gb.c[cb->start];  if (q[0] != 'Z') return 2;   /* ptr->field index      */
	r = &gb.iv[3];         if (r[0] != 7)   return 3;   /* int member array      */
	q = &lb.c[1];          if (q[0] != 'L') return 4;   /* local struct base     */
	tp = &gb.tag;          *tp = 40;                    /* bare &structvar.field */
	if (gb.tag != 40) return 5;

	return gb.tag + 2;                                  /* 42 */
}

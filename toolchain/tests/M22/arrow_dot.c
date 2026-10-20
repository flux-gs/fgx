/* Member access through a struct/union-VALUE field reached by '->' — blk.c's
 * `this->buf.c` (buf a BLK union, c a char[]).  Read/decay/index and indexed
 * store; no deref of the aggregate.  Accesses are chosen to not rely on union
 * overlap (portable across host int=4 / FGX int=2).  -> 42. */
union blk    { char c[8]; int n[4]; };
struct buf   { int logical; union blk buf; };
struct buf   gb;

int main(void)
{
	struct buf *p;
	char       *q;

	p = &gb;
	gb.buf.c[0] = 'A';
	gb.buf.c[1] = 'B';
	gb.buf.n[3] = 7;                 /* n[3]: bytes 6-7 (FGX) / 12-15 (host) */

	q = p->buf.c;               if (q[0]       != 'A') return 1;  /* decay        */
	if (p->buf.c[1] != 'B')                           return 2;  /* char index   */
	if (p->buf.n[3] != 7)                             return 3;  /* int index    */

	p->buf.c[2] = 'Z';          if (gb.buf.c[2] != 'Z') return 4; /* indexed store*/
	p->buf.c[0] = p->buf.c[1];  if (gb.buf.c[0] != 'B') return 5; /* read+store   */

	return 42;
}

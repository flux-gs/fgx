/* Postfix chain on a function-call RESULT — `f()->field`, `f()->arr[i]`,
 * `f()[i]` (elvis cut.c's `blkget(first)->c`).  Func now carries the return
 * struct id; the call-return value (A + its bank in _fcc_ptr+2) feeds the same
 * postfix loop as a parenthesized value, and emit_arrow_chain decays an
 * in-struct char/int array field.  -> 42. */
struct node { int v; char c[4]; struct node *next; };
struct node n0, n1;
int garr[4];

struct node *getn(int i) { return i ? &n1 : &n0; }
int         *getarr(void) { return garr; }

int main(void)
{
	n0.v = 10; n1.v = 30; n0.next = &n1;
	n0.c[0] = 'Z';
	garr[2] = 2;

	if (getn(0)->v       != 10)  return 1;   /* scalar field           */
	if (getn(0)->next->v != 30)  return 2;   /* ptr field + chain      */
	if (getn(0)->c[0]    != 'Z') return 3;   /* array-field decay + [] */
	if (getarr()[2]      != 2)   return 4;   /* call()[i]              */

	return getn(0)->v + getn(0)->next->v + getarr()[2];   /* 10+30+2 = 42 */
}

/* Cast to a struct-tag pointer type: `(struct TAG *)0` and `(struct TAG *)expr`
 * — input.c's `for (prev = (struct _DIG *)0, dp = digs; ...)`.  The cast detector
 * now recognizes the `struct`/`union` keyword, resolves (or forward-creates) the
 * tag, and yields LT_STRUCT_PTR carrying the tag id so `->` works on the result.
 * -> 42. */
struct node { int v; struct node *next; };
struct node n0;
struct node n1;

int main(void)
{
	struct node *p;

	n0.v = 40;
	n0.next = (struct node *)0;
	n1.v = 2;
	n1.next = &n0;

	p = (struct node *)0;
	if (p != (struct node *)0) return 1;      /* null == null */

	p = &n1;
	if (p->next == (struct node *)0) return 2; /* n1.next = &n0, not null */
	return p->v + p->next->v;                  /* 2 + 40 = 42 */
}

/* c26_take.c — extern callee pinned in a DIFFERENT code bank (construct 26).
 * Receives a struct BY VALUE from a STATEMENT-context call site and stores the
 * field sum into a data-seg global for the caller-side checker. */
struct c26_s { int a; int b; int c; };

int c26_result = 0;

void c26_take(struct c26_s s)
{
	c26_result = s.a + s.b + s.c;
}

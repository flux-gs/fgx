/* A void-returning function call in a for-init / for-step clause, where the
 * value is DISCARDED — elvis's ChangeText macro expands to
 *   for((beforedo(FALSE)),bavar=1; bavar; (afterdo()),bavar=0) { ... }
 * fcc rejected any void call in an expression ("void-returning function cannot
 * be used in expression"); now it is allowed in the discarded for-clauses while
 * value-consuming contexts (x = vf()) still error.  -> 42. */
int gtrace;

void vbefore(void) { gtrace = gtrace + 1; }
void vafter(void)  { gtrace = gtrace + 10; }

int bavar;

int main(void)
{
	int body;

	gtrace = 0;
	body   = 0;
	for ((vbefore()), bavar = 1; bavar; (vafter()), bavar = 0) {
		body = body + 1;
	}
	if (gtrace != 11) return 1;   /* vbefore (init) + vafter (step) = 1 + 10 */
	if (body != 1)    return 2;   /* body ran exactly once */
	return 42;
}

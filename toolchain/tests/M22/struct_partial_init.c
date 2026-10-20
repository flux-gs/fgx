/* Partial struct brace initializers, formerly rejected with "expected ','
 * between struct field inits": a scalar struct `{ 0 }` (tail fields zero-fill)
 * and a FLAT struct-array whose last element `{ ..., 3 }` is short one field
 * (that field zero-fills).  The zero-fill-on-'}' path now fires in flat mode
 * too, not only inside per-element braces.  -> 42. */
struct kv { int a; int b; };

static struct kv g   = { 0 };            /* a = 0, b = 0 (partial) */
struct kv        arr[] = { 1, 2, 3 };    /* arr[0] = {1,2}, arr[1] = {3,0} */

int main(void)
{
	if (g.a != 0 || g.b != 0)           return 1;
	if (arr[0].a != 1 || arr[0].b != 2) return 2;
	if (arr[1].a != 3 || arr[1].b != 0) return 3;   /* tail zero-filled */
	return 42;
}

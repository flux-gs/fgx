/* struct_sinit.c — SCALAR (non-array) struct brace-init: `struct S g = {...}`.
 * fcc previously rejected this ("brace-initializer requires ... struct[N]"); only
 * an array of struct was allowed.  Now LT_STRUCT (n_elems == 1) routes through the
 * struct-array init parser + emitter, so a scalar struct initializes like one
 * element.  Exercises int and char fields (chars byte-packed since B-8).  -> 42. */
struct s3 { int a; int b; char c; };
struct s3 g = { 40, 2, 7 };

int main(void)
{
	if (g.a != 40) return 1;
	if (g.b != 2)  return 2;
	if (g.c != 7)  return 3;
	return g.a + g.b;          /* 40 + 2 = 42 */
}

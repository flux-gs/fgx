/* M22: `static struct {...} name[] = {...}` as a LOCAL -- an ANONYMOUS struct
 * type, a static local, and a struct ARRAY at once (tcsh ed.screen's
 * `static struct { int key, fun; } ar[] = { {T_kd, F_DOWN_HIST}, ... }`).
 *
 * Static-local structs were already backed by a hidden file-scope global, and
 * both the emitter's struct/struct-array walk and the M22 brace-init parser
 * are shared with file scope -- only the ARRAY case was refused outright.  So
 * this needed sizing the backing global (n_bytes = elem_size * n_elems, with
 * n_elems patched later for the `[]` form) and routing the initializer, not
 * new emission machinery.
 *
 * Both array spellings are covered: sized `[2]` and size-from-initializer
 * `[]`, since the latter is what ed.screen actually writes and it takes the
 * patch-after-counting path.  The values are read back through subscripts so
 * a wrong element stride or a mis-sized global shows up as a wrong total.
 *
 * Returns 42.
 */
static int
sized(void)
{
	static struct {
		int key, fun;
	}      a[2] =
	{
		{ 1, 2 },
		{ 3, 4 }
	};

	return a[0].key + a[0].fun + a[1].key + a[1].fun;	/* 10 */
}

static int
from_init(void)
{
	static struct {
		int lo, hi;
	}      b[] =
	{
		{ 5,  6 },
		{ 7,  8 },
		{ 9, 10 }
	};
	int i, s = 0;

	for (i = 0; i < 3; i++)
		s += b[i].lo + b[i].hi;
	return s;						/* 45 */
}

int main()
{
	int r = 0;

	if (sized() == 10)     r += 21;
	if (from_init() == 45) r += 21;

	return r;			/* 42 */
}

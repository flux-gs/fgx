/* Global `long *` pointer subscript must DEREF the pointer value, not index
 * the pointer's own storage symbol.  Regression for the compress(1) heap-
 * corruption bug: fcc compiled `long *g; g[i]` as a global-ARRAY access
 * (`LDA #g` / `LDA: g,X`, base = &g), so a store landed at &g + i*4 instead of
 * *(g) + i, scribbling ~i*4 bytes across the data segment / shared heap.  The
 * `short *` path was always correct via `[_fcc_ptr]`; only 4-byte-pointee
 * globals (`long *` / `float *`) took the broken symbol-as-array path.
 *
 * The array alias makes the miscompile observable: a buggy store never reaches
 * `larr`, so the read-back through the array fails (return 1/2).  A buggy load
 * reads the pointer's own storage, not `larr` (return 3).  Exit 42. */
long  larr[8];
long *lp;

int main(void)
{
	int i;

	for (i = 0; i < 8; i++)
		larr[i] = 0L;

	lp = larr;
	lp[3] = 100L;              /* STORE through the long* pointer   */
	lp[7] = 12345L;
	if (larr[3] != 100L)   return 1;   /* read via ARRAY: store must hit larr */
	if (larr[7] != 12345L) return 2;

	larr[5] = 42L;
	if (lp[5] != 42L)      return 3;   /* READ through pointer: must deref     */
	if (lp[3] != 100L)     return 4;
	if (lp[7] != 12345L)   return 5;

	return (int)lp[5];                 /* 42 */
}

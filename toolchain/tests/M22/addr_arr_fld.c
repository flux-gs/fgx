/* Address-of a field within a struct-array element — blk.c's `&blk[i].buf`
 * (`bp != &blk[i].buf`).  A = &arr[i]; add the field offset; result is a pointer
 * to the field.  Exercises a scalar field (-> int*) and union-field address
 * comparison (the blk `!=` idiom).  -> 42. */
union blk  { char c[8]; int n[4]; };
struct buf { int logical; union blk buf; };
struct buf arr[4];

int main(void)
{
	int  i;
	int *lp;

	i = 1;
	arr[0].logical = 3;
	arr[1].logical = 5;

	lp = &arr[i].logical;  if (lp[0] != 5) return 1;   /* &arr[i].scalar -> int* */
	lp = &arr[0].logical;  if (lp[0] != 3) return 2;
	if (&arr[0].buf == &arr[1].buf) return 3;          /* distinct union addrs   */
	if (&arr[i].buf != &arr[1].buf) return 4;          /* i=1: equal (!= idiom)  */

	return 37 + arr[i].logical;                        /* 37 + 5 = 42 */
}

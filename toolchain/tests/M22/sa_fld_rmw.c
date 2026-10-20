/* Read-modify-write of a scalar field on a struct-ARRAY element at statement
 * position — elvis blk.c's `blk[j].logical--` (post-dec of `unsigned short
 * logical` inside `struct _blkbuf blk[NBUFS]`).  A = &arr[i], _fcc_ptr+2 = its
 * bank; the field RMW mirrors the struct-pointer G31 twin.  Exercises postfix
 * '++'/'--' and compound '+='/'-=' on the same struct-array-element field.
 * Field `logical` sits at offset 8 (after `char buf[8]`), so the field-offset
 * add is exercised too.  unsigned short is 16-bit on host and FGX, so the
 * values are portable.  -> 42. */
struct blkbuf { char buf[8]; unsigned short logical; int dirty; };
struct blkbuf blk[4];

int main(void)
{
	int j;

	for (j = 0; j < 4; j++) { blk[j].logical = 10; blk[j].dirty = 0; }

	blk[2].logical--;        /* 10 -> 9  (the elvis construct)   */
	blk[0].logical++;        /* 10 -> 11 (postfix ++ twin)       */
	blk[1].logical += 5;     /* 10 -> 15 (compound += on field)  */
	blk[3].logical -= 3;     /* 10 -> 7  (compound -= on field)  */

	/* 11 + 15 + 9 + 7 = 42 */
	return blk[0].logical + blk[1].logical + blk[2].logical + blk[3].logical;
}

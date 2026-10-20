/* G52 regression: struct pointer arithmetic through ptr-ptr declarations —
 * `*pp + n` must scale by sizeof(struct), not the int default 2.  The
 * struct_id was dropped for any declaration deeper than one '*' (block
 * locals, ANSI params, K&R params, return types; globals already had the
 * any-depth rule), so ls getdir's grow guard compared fp against fp0+2n
 * instead of fp0+28n and never fired — the array overran into live heap
 * chunks (H1 ls corruption root cause).  elem_size_for now dies loudly on
 * a struct pointer with unknown sid, so a regression is a compile error
 * or a wrong exit, never a silent stride-2.  Exit 42. */
struct s28 { int tag; char pad[26]; };  /* 28 B, afile-sized */

struct s28 arr[6];

int fknr(pp, n)
	struct s28 **pp;
	int n;
{
	struct s28 *q;
	q = *pp + n;
	return q->tag;
}

int fansi(struct s28 **pp)
{
	struct s28 *q;
	q = *pp + 2;
	return q->tag;
}

int floc(void)
{
	struct s28 *p;
	struct s28 **pp;
	p = arr;
	pp = &p;
	return (int)(*pp + 3 - arr);    /* ptr-diff through the deref: 3 */
}

int main(void)
{
	struct s28 *p;
	p = arr;
	arr[2].tag = 9;
	arr[3].tag = 30;
	if (fknr(&p, 3) != 30) return 1;
	if (fansi(&p) != 9)    return 2;
	if (floc() != 3)       return 3;
	return 42;
}

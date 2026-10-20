/* M22: brace initializers that need MORE THAN ONE SLOT PER FIELD.
 *
 * The initializer model stored exactly one value slot per struct FIELD and
 * derived the element count by dividing n_init_values by n_fields, so two
 * perfectly ordinary shapes could not be represented at all:
 *
 *   - a member that is itself a STRUCT, taking a nested list
 *     (`static struct rusage zru = {{0L,0L},{0L,0L},0,...}` -- tcsh sh.proc);
 *   - a member that is an ARRAY, taking one value per element
 *     (`struct varent nulargv = {nulvec, STRargv, 0}` -- tcsh sh.dol, where
 *     the 0 lands on `struct varent *v_link[3]`).
 *
 * Slots are now LEAVES (struct_init_leaves): a struct member contributes its
 * own leaves, a non-char array member one per element.  For an all-scalar
 * struct the leaf list IS the field list, which is what keeps every existing
 * initializer byte-identical.
 *
 * K&R A.8.7 also allows the nested list to be ELIDED, and allows it to be
 * SHORT.  The short case is the one that silently corrupts if brace groups are
 * merely skipped rather than tracked: `{7L}` for a two-member timeval must
 * leave usec 0, NOT absorb the following member's value.  The `part` legs
 * below fail loudly if group extents are not honoured.
 *
 * Returns 42.
 */
struct tv {
	long sec;
	long usec;
};

struct ru {
	struct tv ut;			/* struct-VALUE member -> nested list */
	struct tv st;
	long      m;
	int       n;
};

struct ve {
	char      **vec;
	char       *name;
	struct ve  *link[3];		/* ARRAY member -> one leaf per element */
	int         bal;
};

char  *nv[1];
char   nm[4];

static struct ru zru  = {{1L, 2L}, {3L, 4L}, 5L, 6};
static struct ru part = {{7L},     {8L},     0L, 0};   /* SHORT groups */
static struct ve nulv = {nv, nm, 0};                   /* elided array list */

int main()
{
	int r = 0;

	if (zru.ut.sec == 1L && zru.ut.usec == 2L) r += 6;
	if (zru.st.sec == 3L && zru.st.usec == 4L) r += 6;
	if (zru.m == 5L && zru.n == 6)             r += 6;

	/* usec must be 0 -- if a short group spilled, it would be 8 (the next
	 * member's value) and the whole tail would be shifted by one. */
	if (part.ut.sec == 7L && part.ut.usec == 0L) r += 8;
	if (part.st.sec == 8L && part.st.usec == 0L) r += 8;

	if (nulv.vec == nv && nulv.name == nm)     r += 4;
	if (nulv.link[0] == 0 && nulv.link[1] == 0 &&
	    nulv.link[2] == 0 && nulv.bal == 0)    r += 4;

	return r;			/* 6+6+6+8+8+4+4 = 42 */
}

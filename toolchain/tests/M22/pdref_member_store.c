/* Deref-store through a struct-member POINTER lvalue: `*sp->cp = rhs`.
 * The `*IDENT' deref-store fast path used to commit to IDENT (`sp') as the
 * whole deref operand and die "expected '='" on the following `->'; the fix
 * peeks past IDENT and, on a postfix continuation (`->', `.', `['), falls
 * through to the general unary path so `*(sp->cp)' stores correctly.  stty(1)'s
 * special[] table drives its erase/kill/intr/... setters exactly this way.
 * The `-1' store also proves the full 16-bit short is written (not just the
 * low byte).  -> 42. */
short a, b, c;

struct ent {
	char	*name;
	short	*cp;
} tbl[3];

int main(void)
{
	struct ent *sp;

	tbl[0].name = "a"; tbl[0].cp = &a;
	tbl[1].name = "b"; tbl[1].cp = &b;
	tbl[2].name = "c"; tbl[2].cp = &c;

	sp = &tbl[0];
	*sp->cp = 10;              /* a = 10 */
	sp = &tbl[1];
	*sp->cp = -1;             /* b = -1 (0xFFFF: full 16-bit store) */
	sp = &tbl[2];
	*sp->cp = 33;             /* c = 33 */

	if (a != 10)   return 1;
	if (b != -1)   return 2;   /* low-byte-only store would give 0x00FF */
	if (c != 33)   return 3;

	return 42;
}

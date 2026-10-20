/* c43_ptrelemfield.c — construct 44: `&p[i].field` where p is a POINTER to a
 * struct in ANOTHER BANK.  The address must carry p's bank, scale the index by
 * the whole struct, and add the member offset — all three, together.
 *
 * WHY THIS EXISTS.  Until !128 this did not PARSE: the `&`-path had grown a
 * dot-chain case on its ARRAY arm and never on its POINTER arm, so `&p[i].f`
 * fell through with the '.' unread.  K&R A.7.3.1 (p.162) says `E1[E2]` is
 * "identical (by definition) to *((E1)+(E2))", which makes the POINTER form the
 * primitive one and the array form the derived one — the implementation had it
 * backwards.  Nothing in the tree had written the construct, which is why a
 * year-old fixture broke the day a pool stopped being an array (the VFS pools,
 * !128) and a TYPE change surfaced as a SYNTAX error.
 *
 * So the parse is new, and a new parse path is exactly where a silently WRONG
 * ADDRESS hides.  c14 already covers struct-pointer arithmetic, but over a
 * 4-byte struct in the DATA bank; this is a non-power-of-two stride reached
 * through a far pointer, which is the shape the VFS vnode pool actually has.
 *
 * The checks are DIFFERENCES against the base rather than absolute addresses,
 * so the construct is independent of where the loader put the segment — and
 * each one fails distinctly: a dropped bank, a wrong stride and a wrong member
 * offset cannot alias into the same pass.
 */
struct c44_e {
	long  a;                /* +0  */
	long  b;                /* +4  */
	int   c;                /* +8  */
	char  pad[13];          /* odd tail -> sizeof 23 -> padded to 24 */
};

struct c44_e c44_arr[4];

int c44_check(void)
{
	struct c44_e *p = c44_arr;
	int es = (int)sizeof(struct c44_e);

	/* Stride: element 2 must sit exactly 2*sizeof past element 0.  `p + 2`
	 * would exercise c14's path; the SUBSCRIPT-then-member form is this
	 * construct's whole point. */
	if ((int)((char *)&p[2].a - (char *)&p[0].a) != 2 * es) return 0;

	/* Member offset must ride along, and must not be folded into the index. */
	if ((int)((char *)&p[2].c - (char *)&p[2].a) != 8)      return 0;

	/* Both together, against the BASE — the composition is what the address
	 * of a pool entry's field actually is. */
	if ((int)((char *)&p[3].c - (char *)p) != 3 * es + 8)   return 0;

	/* THE BANK.  A far pointer whose bank was dropped still produces correct
	 * DIFFERENCES above -- they are 16-bit subtractions -- so the offsets
	 * prove nothing about it.  Writing through the computed address and
	 * reading it back through the ARRAY name is what proves both spellings
	 * reached the same object in the same bank. */
	p[1].c = 0x5A5A;
	if (c44_arr[1].c != 0x5A5A)                             return 0;
	c44_arr[1].c = 0x1234;
	if (p[1].c != 0x1234)                                   return 0;

	/* And the array spelling of the same address must agree with the pointer
	 * spelling -- K&R A.7.3.1 says they are the same expression. */
	if ((char *)&c44_arr[3].c != (char *)&p[3].c)           return 0;

	return 1;
}

/* Subscripting a struct member that is a POINTER, read as an rvalue --
 * tcsh sh.c:1116 `xfree((ptr_t) fbuf[i])`, where the fbuf macro expands to
 * B.Bfbuf and Bfbuf is `Char **`.
 *
 * K&R A.7.3: `E1->MOS` is the same as `(*E1).MOS`, and A.7.3.1 makes E1[E2]
 * identical to *(E1+E2) with lvalue-ness propagating along the chain -- so
 * `p->f[i]` and `s.f[i]` are ONE postfix production.  fcc handled the arrow
 * spelling but not the dot: build_dot_access consumes '[' only when the leaf
 * field is an ARRAY, so a POINTER leaf fell through with '[' unread and the
 * caller reported a bogus "expected ')'"/"expected ';'".
 *
 * The sibling dot_ptrfield_subscript_store covers the STORE direction for a
 * SINGLE-pointer leaf (`char *code`), which already worked; this is the READ,
 * which is where the gap was.  Both spellings are exercised so the dot form
 * can never silently diverge from the arrow form again.
 *
 * KNOWN REMAINING EDGE, deliberately not covered here: a STORE through a
 * subscripted DOUBLE-pointer member (`B.pp[0] = q` with `char **pp`) still
 * dies with "expected '='" -- the dot-led store path handles a single-pointer
 * leaf but not a double.  No tcsh TU needs it, and it fails CLOSED (a hard
 * error, never a silent mis-store), so it waits for a port that does.  -> 42
 */
struct b { char **pp; char *p; unsigned int ua[4]; int n; };
struct e { char **pp; };
struct f2 { struct e e2; };
struct f2 F;
struct b  B;
struct b *P;
char     *r0, *r1, *r2;
char      s0[4], s1[4];
char     *vec[3];

int main(void)
{
	int i;

	s0[0] = 'A'; s0[1] = 0;
	s1[0] = 'B'; s1[1] = 0;
	vec[0] = s0; vec[1] = s1; vec[2] = 0;
	B.pp = vec; B.n = 2;
	P = &B;

	i = 0;
	r0 = B.pp[i];                    /* dot, pointer member, subscript READ */
	if (r0[0] != 'A') return 1;

	i = 1;
	r1 = P->pp[i];                   /* arrow spelling: must agree */
	if (r1[0] != 'B') return 2;

	r2 = (char *) B.pp[0];           /* the tcsh shape: cast of the read */
	if (r2[0] != 'A') return 3;

	if (B.pp[1][0] != 'B') return 4; /* chained subscript off the member */

	B.p = s0;                        /* single-pointer leaf: store works */
	B.p[0] = 'C';
	if (B.p[0] != 'C') return 5;

	/* COMPARE context -- this is where the gate actually fires for a member
	 * ARRAY, and where unsignedness had to be carried out of the walker.
	 * 50000 is 0xC350: negative if the compare goes signed, so a regression
	 * here silently takes the wrong branch instead of erroring. */
	B.ua[0] = 50000;
	i = 0;
	if (!(B.ua[i] > 100)) return 6;

	if (B.pp[2] != 0) return 7;      /* condition-context read */

	F.e2.pp = vec;                   /* nested dot then subscript */
	if (F.e2.pp[1][0] != 'B') return 8;

	return 42;
}

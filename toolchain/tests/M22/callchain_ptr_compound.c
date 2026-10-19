/* `f()->ptr += n' -- compound assignment on a POINTER leaf whose chain base is
 * a CALL RESULT (apple/fgx#155).  The operand was never scaled, so the pointer
 * moved one byte instead of one element.
 *
 * This is the EXPRESSION twin of the statement arm fixed in apple/fgx#154, and
 * the reason it survived that pass is worth stating: a statement whose chain
 * base is a call is BUILT by the expression layer and only then wrapped as a
 * statement, so it never reaches the statement arm at all.  Fixing one and
 * assuming the other followed is exactly the mistake.
 *
 * `struct B' is SIX bytes, so a one-byte bump lands between elements and reads
 * neither neighbour's value.  A runtime operand is included because a constant
 * folds and reaches different code.  The postfix ++ cases guard the #154 fix
 * against regression on the same path.  -> 42 */
struct B    { int a; int b; int c; };                  /* 6 bytes */
struct hold { int pad; struct B *pb; struct hold *nx; };

struct hold	hroot;
struct hold	other;
struct B	blk[4];
struct B	*pvv[4];
int		ivv[4];
int		calls;

struct hold *
hf()
{
	calls++;
	return &hroot;
}

struct B **
pvec()
{
	calls++;
	return pvv;
}

int *
ivec()
{
	calls++;
	return ivv;
}

int main(void)
{
	struct B *q;
	int n;

	blk[0].a = 10; blk[1].a = 11; blk[2].a = 12;
	hroot.nx = &other;
	n = 2;

	hroot.pb = &blk[0];  hf()->pb += 1;   if (hroot.pb->a != 11) return 1;
	hroot.pb = &blk[0];  hf()->pb += n;   if (hroot.pb->a != 12) return 2;
	hroot.pb = &blk[2];  hf()->pb -= 1;   if (hroot.pb->a != 11) return 3;
	hroot.pb = &blk[2];  hf()->pb -= n;   if (hroot.pb->a != 10) return 4;

	/* multi-hop from the call result */
	other.pb = &blk[0];  hf()->nx->pb += 1;
	if (other.pb->a != 11)  return 5;
	other.pb = &blk[0];  hf()->nx->pb += n;
	if (other.pb->a != 12)  return 6;

	/* ++/-- on the same path (apple/fgx#154) must stay right */
	hroot.pb = &blk[0];  hf()->pb++;      if (hroot.pb->a != 11) return 7;
	hroot.pb = &blk[1];  hf()->pb--;      if (hroot.pb->a != 10) return 8;

	/* VALUE context.  K&R A.7.17: the value of `E1 op= E2' has the type of
	 * E1 -- a POINTER here, not an int.  Typed int, the enclosing assignment
	 * treats it as an int-to-pointer conversion and stamps a bank on it. */
	hroot.pb = &blk[0];  q = (hf()->pb += 1);
	if (q->a != 11)         return 9;
	if (hroot.pb->a != 11)  return 10;

	hroot.pb = &blk[2];  q = (hf()->pb -= n);
	if (q->a != 10)         return 11;

	/* the base is evaluated once per statement, not once per mention */
	calls = 0;
	hroot.pb = &blk[0];  hf()->pb += 1;
	if (calls != 1)         return 12;

	/* `f()[i] OP= rhs' -- an INDEXED compound assignment off a call result.
	 * The old lowering rewrote it as `base[i] = base[i] OP rhs', putting the
	 * base in the tree twice, so the CALL was emitted twice -- K&R A.7.17
	 * says E1 is evaluated only once -- and with a pointer element the
	 * second walk freed the base's register out of order and the compiler
	 * stopped with an internal error.  The counter is the assertion for the
	 * first half; the values are the assertion for the second. */
	ivv[1] = 50;
	calls = 0;
	ivec()[1] += 1;         if (ivv[1] != 51)  return 13;
	if (calls != 1)                            return 14;
	ivec()[1] -= 3;         if (ivv[1] != 48)  return 15;

	pvv[1] = &blk[0];
	calls = 0;
	pvec()[1] += 1;         if (pvv[1]->a != 11) return 16;
	if (calls != 1)                              return 17;
	pvv[1] = &blk[2];
	pvec()[1] -= n;         if (pvv[1]->a != 10) return 18;
	pvv[1] = &blk[0];
	pvec()[1] += n;         if (pvv[1]->a != 12) return 19;

	return 42;
}

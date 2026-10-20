/* Pointer arithmetic on a STRUCT pointer scales by the struct, not by one
 * byte (apple/fgx#154).  K&R A.7.7: the integer added to a pointer is scaled
 * by the size of the object pointed to.  ptr_stride() returns 0 for a struct
 * pointer by design -- the size needs the struct id, which the type word does
 * not carry -- and every site that papered the 0 over with 1 advanced by one
 * byte, silently.
 *
 * `three' is SIX bytes on purpose.  A stride fix built out of ASL would pass
 * every power-of-two case and still be wrong here, and struct sizes are not
 * powers of two in general.
 *
 * The shapes are separate cases because they reach separate emitters: a
 * pointer VARIABLE, a `->' member, a `.' member, a multi-hop chain, a deref,
 * and both spellings of ++/-- against +=/-=.  Getting one right says nothing
 * about the others -- `gr++' was correct the whole time `gr += 1' was not.
 * -> 42 */
struct four { int x; int y; };                  /* 4 bytes */
struct three { int a; int b; int c; };          /* 6 bytes */
struct big { int v; char pad[171]; };           /* 174 rounded: 5 bits set,
                                                 * so the scale cannot inline
                                                 * and must reach _fcc_mul16 */
struct hold { struct four *fp; struct hold *nx; struct three *tp;
              struct big *bp; };

struct four	f4[4];
struct three	t3[4];
struct big	b1[4];
int		iv[4];
struct hold	root;
struct hold	other;
struct hold	gh;
struct hold	*gp;			/* a GLOBAL pointer base for &gp->tp[i] */			/* the STATIC-base twin of &p->tp[i] */
struct four	*gr;
struct three	*gt;
struct big	*gb;
struct four	*parr[4];              /* ARRAY of pointers */
struct three	*tarr[4];
int		*iarr[4];
struct four	**ppg;

/* Returns 1, and drags a pointer through direct-page scratch on the way so a
 * caller that stashed something there loses it. */
int
bump()
{
	struct four *local;

	local = &f4[1];
	gr = local;
	return local->x - 10;
}

int main(void)
{
	struct hold	*p;
	struct four	**pp;

	f4[0].x = 10; f4[1].x = 11; f4[2].x = 12;
	t3[0].a = 20; t3[1].a = 21; t3[2].a = 22;
	p = &root;
	root.nx = &other;

	/* pointer VARIABLE: ++/-- were already right, += was not */
	gr = &f4[0];  gr++;      if (gr->x != 11)  return 1;
	gr = &f4[0];  ++gr;      if (gr->x != 11)  return 2;
	gr = &f4[1];  gr--;      if (gr->x != 10)  return 3;
	gr = &f4[0];  gr += 1;   if (gr->x != 11)  return 4;
	gr = &f4[2];  gr -= 2;   if (gr->x != 10)  return 5;
	gr = &f4[0];  gr += 2;   if (gr->x != 12)  return 6;

	/* six-byte element: no power of two anywhere near it */
	gt = &t3[0];  gt++;      if (gt->a != 21)  return 7;
	gt = &t3[0];  gt += 1;   if (gt->a != 21)  return 8;
	gt = &t3[0];  gt += 2;   if (gt->a != 22)  return 9;
	gt = &t3[2];  gt -= 2;   if (gt->a != 20)  return 10;
	gt = &t3[0];  ++gt;      if (gt->a != 21)  return 11;

	/* '->' member */
	root.fp = &f4[0];  p->fp++;     if (p->fp->x != 11)  return 12;
	root.fp = &f4[0];  ++p->fp;     if (p->fp->x != 11)  return 13;
	root.fp = &f4[1];  p->fp--;     if (p->fp->x != 10)  return 14;
	root.fp = &f4[0];  p->fp += 1;  if (p->fp->x != 11)  return 15;
	root.tp = &t3[0];  p->tp += 2;  if (p->tp->a != 22)  return 16;
	root.tp = &t3[0];  p->tp++;     if (p->tp->a != 21)  return 17;

	/* '.' member of a named struct */
	root.fp = &f4[0];  root.fp++;   if (root.fp->x != 11) return 18;
	root.fp = &f4[0];  ++root.fp;   if (root.fp->x != 11) return 19;
	root.tp = &t3[0];  root.tp++;   if (root.tp->a != 21) return 20;

	/* multi-hop chain */
	other.fp = &f4[0]; p->nx->fp++;    if (p->nx->fp->x != 11) return 21;
	other.fp = &f4[0]; ++p->nx->fp;    if (p->nx->fp->x != 11) return 22;
	other.tp = &t3[0]; p->nx->tp += 1; if (p->nx->tp->a != 21) return 23;

	/* through a deref */
	gr = &f4[0]; pp = &gr; *pp += 1;   if (gr->x != 11) return 24;
	gr = &f4[0]; pp = &gr; (*pp)++;    if (gr->x != 11) return 25;
	gt = &t3[0];                       /* six-byte deref */
	{ struct three **qq; qq = &gt; *qq += 1; if (gt->a != 21) return 26; }

	/* a RUNTIME operand, so the scale cannot be folded into a constant */
	{ int n; n = 2;
	  gr = &f4[0]; gr += n;  if (gr->x != 12) return 27;
	  gt = &t3[0]; gt += n;  if (gt->a != 22) return 28; }

	/* A RUNTIME operand on the MEMBER, DOTFIELD, CHAIN and DEREF paths
	 * too -- the constant form folds and reaches different code. */
	{ int n; struct four **pp; n = 2;
	  root.fp = &f4[0];  p->fp += n;      if (p->fp->x != 12)     return 29;
	  root.fp = &f4[0];  root.fp += n;    if (root.fp->x != 12)   return 30;
	  other.fp = &f4[0]; p->nx->fp += n;  if (p->nx->fp->x != 12) return 31;
	  gr = &f4[0]; pp = &gr; *pp += n;    if (gr->x != 12)        return 32;
	  root.tp = &t3[0];  p->tp += n;      if (p->tp->a != 22)     return 33; }

	/* `-=' on every path, not just the pointer variable */
	{ int n; struct four **pp; n = 2;
	  root.fp = &f4[2];  p->fp -= n;      if (p->fp->x != 10)     return 34;
	  root.fp = &f4[2];  root.fp -= n;    if (root.fp->x != 10)   return 35;
	  other.fp = &f4[2]; p->nx->fp -= n;  if (p->nx->fp->x != 10) return 36;
	  gr = &f4[2]; pp = &gr; *pp -= n;    if (gr->x != 10)        return 37;
	  root.tp = &t3[2];  p->tp -= 1;      if (p->tp->a != 21)     return 38; }

	/* A LOCAL struct's dotfield -- the globals above take another path */
	{ struct hold h;
	  h.fp = &f4[0];  h.fp++;             if (h.fp->x != 11)      return 39;
	  h.fp = &f4[0];  h.fp += 2;          if (h.fp->x != 12)      return 40;
	  h.fp = &f4[2];  h.fp -= 2;          if (h.fp->x != 10)      return 41; }

	/* A stride the scale cannot inline: 174 has five bits set, so this is
	 * the only case that reaches the _fcc_mul16 arm. */
	iv[0] = 70; iv[1] = 71; iv[2] = 72;
	b1[0].v = 60; b1[1].v = 61; b1[2].v = 62;
	{ int n; n = 2;
	  gb = &b1[0];  gb++;      if (gb->v != 61)  return 43;
	  gb = &b1[0];  gb += 1;   if (gb->v != 61)  return 44;
	  gb = &b1[0];  gb += n;   if (gb->v != 62)  return 45;
	  gb = &b1[2];  gb -= n;   if (gb->v != 60)  return 46;
	  root.bp = &b1[0]; p->bp += n; if (p->bp->v != 62) return 47; }

	/* THE RHS MAY CLOBBER DIRECT-PAGE SCRATCH.  A pointer field's bank is
	 * staged in _fcc_ptr by the load, the RHS runs next, and a CALL is free
	 * to overwrite it -- so the bank must never be read back and restored.
	 * bump() also touches pointers itself, which is what made it a probe. */
	root.fp = &f4[0];  p->fp += bump();      if (p->fp->x != 11)   return 48;
	root.fp = &f4[0];  root.fp += bump();    if (root.fp->x != 11) return 49;
	other.fp = &f4[0]; p->nx->fp += bump();  if (p->nx->fp->x != 11) return 50;

	/* A POINTER ELEMENT of an array.  The element ADDRESS was always
	 * scaled; the OPERAND was not, so `parr[i] += 1' moved one byte.  The
	 * struct id for an ARRAY of struct pointers was not recorded either --
	 * only ISPTR globals got one -- so the size was unknown here too. */
	{ int n; n = 2;
	  parr[0] = &f4[0];  parr[0] += 1;   if (parr[0]->x != 11)  return 51;
	  parr[1] = &f4[0];  parr[1] += n;   if (parr[1]->x != 12)  return 52;
	  parr[2] = &f4[2];  parr[2] -= n;   if (parr[2]->x != 10)  return 53;
	  tarr[0] = &t3[0];  tarr[0] += 1;   if (tarr[0]->a != 21)  return 54;
	  tarr[1] = &t3[0];  tarr[1] += n;   if (tarr[1]->a != 22)  return 55;
	  iarr[0] = &iv[0];  iarr[0] += 1;   if (*iarr[0] != 71)    return 56;
	  iarr[1] = &iv[0];  iarr[1] += n;   if (*iarr[1] != 72)    return 57;
	  ppg = &parr[0]; parr[0] = &f4[0]; *ppg += 1;
	                                     if (parr[0]->x != 11)  return 58; }

	/* THE ADDRESS-OF form of a chained subscript: `&p->tp[i]'.
	 *
	 * A DIFFERENT EMITTER from every case above, and it was wrong in TWO
	 * places that hid each other.  The parser read the stride as
	 * `ptr_stride(chain_ty); if (!es) es = 2' -- papering over the same
	 * struct sentinel #154 is about, but with 2 rather than 1 -- and the
	 * N_ADDR_CHAIN_IDX emitter scaled only `es == 2' and `es == 4', so any
	 * other size emitted NO SCALING AT ALL.  The parser could therefore
	 * only ever hand it 1, 2 or 4 and the missing arms looked unreachable.
	 *
	 * `three' being SIX bytes is what makes this discriminate: with the
	 * parser alone fixed the stride became 1, and with the emitter alone
	 * fixed it stayed 2.  Both must be right to land on element 1.
	 *
	 * The STATIC-base twin `&gh.tp[i]' was correct throughout, which is why
	 * this went unnoticed -- the same twin split as apple/fgx#155.  Both
	 * spellings are asserted here so a future fix to one is not mistaken
	 * for a fix to both.  Found by uiomove advancing to its second iovec,
	 * where the wrong address was a WILD POINTER rather than an error. */
	{ int n; struct three *q; struct four *r; n = 1;
	  root.tp = &t3[0];
	  q = &p->tp[1];               if (q != &t3[1])       return 59;
	  q = &p->tp[1];               if (q->a != 21)        return 60;
	  q = &p->tp[n];               if (q != &t3[1])       return 61;
	  q = &p->tp[2];               if (q->a != 22)        return 62;
	  root.fp = &f4[0];
	  r = &p->fp[1];               if (r != &f4[1])       return 63;
	  r = &p->fp[n];               if (r->x != 11)        return 64;
	  /* the multi-hop chain reaches the same emitter with n_hops > 1 */
	  other.tp = &t3[0];
	  q = &p->nx->tp[2];           if (q != &t3[2])       return 65;
	  q = &p->nx->tp[2];           if (q->a != 22)        return 66;
	  /* and the static-base twin, correct all along */
	  gh.tp = &t3[0];
	  q = &gh.tp[1];               if (q != &t3[1])       return 67;
	  q = &gh.tp[n];               if (q->a != 21)        return 68; }

	/* THE MUL16 ARM, through the repaired emitter.  Cases 59-68 use strides
	 * 6 and 4 and BOTH of those inline as shift-adds, so they never reach
	 * emit_index_scale's general multiply -- the arm `struct big' exists in
	 * this fixture to exercise (174 bytes, five bits set) was reachable only
	 * through the `gb += n' family above, which is a different emitter from
	 * `&p->bp[i]'.  Without this, a fix that scaled correctly for shift-add
	 * strides and wrongly for multiplied ones would pass. */
	{ int n; struct big *w; n = 2;
	  root.bp = &b1[0];
	  w = &p->bp[1];               if (w != &b1[1])       return 69;
	  w = &p->bp[n];               if (w->v != 62)        return 70; }

	/* The two base shapes 59-68 leave uncovered: a GLOBAL pointer as the
	 * chain base (the sym_gv arm rather than sym_lc), and a LOCAL struct's
	 * dotfield.  Each reaches the address-of walker by its own route. */
	{ int n; struct three *q; struct hold hl; n = 1;
	  gp = &root;  root.tp = &t3[0];
	  q = &gp->tp[1];              if (q != &t3[1])       return 71;
	  q = &gp->tp[n];              if (q->a != 21)        return 72;
	  hl.tp = &t3[0];
	  q = &hl.tp[1];               if (q != &t3[1])       return 73;
	  q = &hl.tp[n];               if (q->a != 21)        return 74; }

	return 42;
}

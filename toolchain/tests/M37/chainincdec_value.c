/* chainincdec_value: `chain++` where the VALUE is used (apple/fgx#86).
 *
 * The statement form landed first (M37/chainincdec) because that is what the
 * VFS port needs -- `bp->b_vp->v_numoutput++` is 4.3BSD-Reno's own spelling in
 * vfs_bio.c's bwrite -- and as a statement the value is discarded, so `++chain`
 * and `chain++` are the same operation.  In value position they are not: the
 * result has to be the OLD one.
 *
 * K&R A.7.4.1 p.166 takes ++/-- on any modifiable lvalue and says nothing about
 * how many hops reached it, so the one-hop limit was an artefact of which arm
 * saw the expression, not a rule.  The read-modify-write that keeps the old
 * value already existed (N_LV_INCDEC_E + AF_RET_OLD, the `(*p)++` node); only
 * the parse was missing, so a first member that was itself a struct pointer
 * fell through to the chain READER and the '++' was reported as a missing ';'.
 *
 * Ordinary ANSI C, so the host compiler validates it directly.  -> 72:
 *   v = 10 (n 10->11),  w = 11 (n 11->10),  x = 20 (m 20->21),
 *   plus I.n 10 and I.m 21. */
struct inner { int n; int m; };
struct outer { struct inner *ip; };
struct inner  I;
struct outer  O;
struct outer *op;

int
main()
{
	int v, w, x;

	I.n = 10; I.m = 20;
	O.ip = &I;
	op   = &O;

	v = op->ip->n++;
	w = op->ip->n--;
	x = op->ip->m++;
	return v + w + x + I.n + I.m;
}

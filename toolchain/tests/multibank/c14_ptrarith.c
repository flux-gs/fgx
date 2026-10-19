/* c14_ptrarith.c — construct 14: pointer arithmetic over a data-bank array of
 * structs.  sp+2 must advance by 2*sizeof(struct) AND keep the bank; p[i] indexed
 * access likewise.  Mole: sed "RE botch" struct-ptr arith stride.
 *
 * NOTE: does NOT use pointer SUBTRACTION (sp2 - sp).  fcc currently computes
 * ptr-ptr difference as a raw BYTE difference (no divide by sizeof) -> that is a
 * separate, non-bank fcc arithmetic gap (see the ptr-diff finding), orthogonal to
 * the far-pointer bank class this sweep guards. */
struct c14_pt { int x; int y; };
struct c14_pt c14_g[3] = { {1, 2}, {3, 4}, {5, 6} };

int c14_check(void)
{
	struct c14_pt *sp = c14_g;
	struct c14_pt *sp2 = sp + 2;         /* stride = sizeof(struct); bank preserved */
	return (sp2->x - sp->x) == 4         /* sp2 -> g[2].x=5; sp -> g[0].x=1 */
	    && sp2->y == 6                    /* g[2].y */
	    && c14_g[1].y == 4;              /* p[i] indexed access */
}

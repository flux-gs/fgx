/* fcc2 isel Phase 1 — regression for the far-local load-op fold defect (caught by
 * the 3-lens adversarial review).  pad[126] pushes b's frame slot into the >255
 * band; the inner `a + b` has b as an RHS leaf evaluated under c's push, so a
 * naive `slot_needs_far(lc,0)` gate (checked at ambient g_s_delta==0) would fold
 * it to an un-assemblable `<op> 257,S`.  The fix checks far-ness at the fold's
 * lowering depth (leaf->u0 - 2), so this far local stays UNFOLDED (far path).
 * clang reference: 146. */
int gg;

int main(void)
{
    int pad[126];
    int a = 5, b = 7, c = 9;
    int i;
    for (i = 0; i < 126; i++) pad[i] = i;
    gg = c + (a + b);        /* far-local b: must NOT fold (no >255,S) */
    return gg + pad[125];    /* 9 + (5+7) + 125 = 146 */
}

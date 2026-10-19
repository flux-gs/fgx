/* fcc2 isel Phase 1: RHS-leaf load-op fold for GLOBAL and IMG leaf operands,
 * across all five IrBinKinds.  Each `r <op> g` has a local LHS and a global RHS
 * leaf -> folds to `[CLC|SEC] <op> g`.  imgfold()'s `acc + k` promotes k to a
 * DP-IMG slot -> folds to `<op> _fcc_img{n}`.  clang reference value: 33.
 * (Name kept <=15 chars for the ProDOS DSK link name.) */
int ga = 5, gb = 3, gc = 12, gd = 10, ge = 6;

static int imgfold(void)
{
    int acc = 0, k = 7;
    int i;
    for (i = 0; i < 3; i++) acc = acc + k;   /* k is loop-hot -> img leaf */
    return acc;                               /* 21 */
}

int main(void)
{
    int r = 8;
    r = r + ga;   /* 13   CLC/ADC ga */
    r = r - gb;   /* 10   SEC/SBC gb */
    r = r & gc;   /*  8   AND  gc */
    r = r | gd;   /* 10   ORA  gd */
    r = r ^ ge;   /* 12   EOR  ge */
    return r + imgfold();   /* 12 + 21 = 33 */
}

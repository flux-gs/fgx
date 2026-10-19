/* Runtime int -> pointer conversion reconstitutes into the DATA bank (via
 * PHB = DBR), not bank 0.  This is the 2.11BSD sh/tcsh blok.c arena idiom:
 * round-trip an arena pointer through `int` (Rcheat(a)=(int)a) and cast it
 * back with BLK((int)x).  If the reconstituted pointer landed in bank 0, the
 * store below would hit the wrong bank and g would stay 0 (and the shell's
 * free-block chain walk would loop forever).  A COMPILE-TIME constant int->ptr
 * (NULL, hardware regs) still keeps bank 0 -- the cast gates on N_LIT_INT.
 * Regression for parse_expr.c N_CAST int->ptr arm / emit_fpr_from_a_databank.
 *
 * `i` arrives as a parameter so it is a genuine RUNTIME integer (not a
 * foldable &g constant) -- the cast must take the data-bank arm. */
int g;

int *reconstitute(int i)
{
    return (int *)i;         /* BLK((int)x): runtime int -> data bank, not bank 0 */
}

int main()
{
    int *p = &g;
    int *q = reconstitute((int)p);   /* Rcheat then BLK, through a runtime int */
    *q = 7;                          /* bank-0 reconstitution writes the wrong bank */
    return g;                        /* g == 7 iff q addressed the data bank */
}

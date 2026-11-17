/* B1c-2b correctness gate (GOLDEN-ONLY — no oracle.json entry).  The index
 * sub-expression mutates the base pointer (p++ inside the subscript).  This is
 * UNDEFINED behavior in C (the base read of p and the p++ are unsequenced), so we
 * do NOT assert a runtime value.  The fixture exists to lock in fcc's CONSERVATIVE
 * choice: the mutated subscript must stay UN-PROMOTED (CLC/ADC 1,S / STA _fcc_ptr /
 * PLA / LDA [_fcc_ptr]) — NOT LDA [_fcc_img{k}],Y.  The subscript also loads the
 * pointers p and q, which stage THEIR banks in _fcc_ptr+2, so p's bank is staged
 * again from its slot before the element is read (ir_ptr_bank_clobbered_since),
 * and a base read from its slot keeps p out of the img pairs altogether.  Inspect
 * the golden .s after regen. */
static int d[3];
int main(void)
{
    int *p = d, *q = d, v;
    d[0] = 7; d[1] = 8; d[2] = 9;
    v = p[p++ - q];          /* index mutates p -> stays un-promoted */
    return v;
}

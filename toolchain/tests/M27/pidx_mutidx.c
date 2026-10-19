/* B1c-2b correctness gate (GOLDEN-ONLY — no oracle.json entry).  The index
 * sub-expression mutates the base pointer (p++ inside the subscript).  This is
 * UNDEFINED behavior in C (the base read of p and the p++ are unsequenced), so we
 * do NOT assert a runtime value.  The fixture exists to lock in fcc's CONSERVATIVE
 * choice: the mutated subscript must stay UN-PROMOTED (CLC/ADC 1,S / STA _fcc_ptr /
 * PLA / LDA [_fcc_ptr]) — NOT LDA [_fcc_img{k}],Y — even though p promotes via its
 * other ops (init store + p++ + the base load).  The base_mutated flag (set by the
 * record-time structured-mutation scan) keeps this one op un-promoted while the
 * rest of p's accesses use the img pair.  Inspect the golden .s after regen. */
static int d[3];
int main(void)
{
    int *p = d, *q = d, v;
    d[0] = 7; d[1] = 8; d[2] = 9;
    v = p[p++ - q];          /* index mutates p -> stays un-promoted */
    return v;
}

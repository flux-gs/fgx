/* Regression: (q = ptr) == 0 — a pointer ASSIGNMENT used as a comparison operand,
 * compared to null.  emit_store_ptr_local_lower once preserved the value's offset
 * in Y across the soft-stack bank store, but that slot store (LDY #idx /
 * STA [_fcc_ssp],Y) clobbers Y, so TYA restored the slot index -> (q = ptr) had a
 * garbage offset and (q = ptr) == 0 was wrongly FALSE even for a null pointer.
 * (This spun sed's rline `if((q = saveq) == 0) return(-1)` forever.)  -> 42 */
char *gnull;              /* null {0,0} */
char gbuf[4];
char *gp;                 /* non-null */
int main(void) {
    char *q;
    int r;
    r = 0;
    gp = gbuf;
    if ((q = gnull) == 0) r = r + 1;     /* null    -> true  -> +1   */
    if ((q = gp)    == 0) r = r + 100;    /* nonnull -> false ->  0   */
    if ((q = gp)    != 0) r = r + 41;     /* nonnull -> true  -> +41  */
    return r;                             /* 1 + 41 = 42 */
}

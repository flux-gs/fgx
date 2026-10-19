/* Chained assignment to array elements: `a[i] = b[i] = v` (tr(1)'s
 * `code[i] = vect[i] = 0`).  parse_assign handles a 1-D char/int array-element
 * LHS as a chain link (bracket-matched lookahead, then emit_addr_of_* ->
 * emit_push_ptr -> index -> A-preserving emit_deref_store/_byte).  The return
 * also reads the elements as rvalues, confirming the lookahead doesn't disturb
 * ordinary a[i] reads. */
char a[8];
char b[8];
int  p[4];
int  q[4];
int main(){
    a[0] = b[0] = 5;          /* char-array elem chain */
    p[0] = q[0] = 3;          /* int-array elem chain (scaled index) */
    return a[0] + b[0] + p[0] + q[0];   /* 5 + 5 + 3 + 3 = 16 */
}

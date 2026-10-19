/* Chained assignment through a struct pointer: `a->f = b->f = v` (the tr(1)
 * port's next()'s `s->max = s->last = 0`).  parse_assign handles an `->`member
 * LHS as a chain link; emit_deref_ptr_field_store is now A-preserving so the
 * stored value flows to the outer assignment. */
struct string { int last, max; char *p; } s1;
struct string *sp;
int main(){
    sp = &s1;
    sp->last = sp->max = 9;        /* ->member chain, int leaves */
    return sp->last + sp->max;     /* 9 + 9 = 18 */
}

/* dotfield_ptr_store: `p->structfield.ptrfield = rhs` -- storing a POINTER into
 * a nested struct member reached via `->field.field`.  The `->struct-member.
 * field` store handler only allowed int/char leaves; a pointer leaf now stores
 * a 4-byte pointer (offset+bank) via S_AV_STORE's fpr deref-store-ptr arm
 * (mirrors N_STORE_PTRARR_ELEM).  tcsh sh.hist `np->Hlex.next = lp->next`.
 * -> 42. */
struct hx   { struct node *next; int pad; };
struct node { struct hx Hlex; int v; };

int
main()
{
    struct node  a, b;
    struct node *np, *lp, *r;

    a.v = 42;
    np = &a;
    lp = &b;
    b.Hlex.next = &a;                 /* lp->Hlex.next -> &a */
    np->Hlex.next = lp->Hlex.next;    /* np->Hlex.next = &a (pointer leaf store) */

    r = np->Hlex.next;                /* read the stored pointer */
    return r->v;                      /* a.v == 42 */
}

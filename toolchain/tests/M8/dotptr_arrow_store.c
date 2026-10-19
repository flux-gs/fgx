/* dotptr_arrow_store: `structvar.structptrfield->field = rhs` -- a dot chain
 * reaching a struct-POINTER member, then an arrow store (tcsh sh.parse
 * `alout.next->word = Strspl(...)`).  The dot-led store handler bridges into
 * the S_CHAIN_STORE machinery: fpr_load_sym gives the struct var's ADDRESS,
 * the struct-ptr field is hop0 (deref'd at its offset), then the arrow store.
 * -> 42. */
struct we { char *word; struct we *next; int n; };

int
main()
{
    struct we  alout, b;
    char       buf[4];
    struct we *r;

    buf[0] = 'Z';
    alout.next = &b;
    b.word = (char *) 0;
    b.n = 7;

    alout.next->word = buf;        /* store a char* into alout.next->word */
    alout.next->n = 42;            /* store an int into alout.next->n */

    r = alout.next;
    return (r->word == buf) ? r->n : 0;   /* 42 */
}

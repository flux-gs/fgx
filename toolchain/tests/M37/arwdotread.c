/* An embedded-struct member reached PAST the first arrow hop, then a '.field'
 * READ: `undo->ptr->link.prev` (joe undo.c, uundo -- an intrusive-list LINK()
 * struct one arrow past a pointer member).
 *
 * The G22 arrow-chain reader in build_arrow_access stopped at the struct-VALUE
 * leaf (`link`, not a struct pointer) and built N_ARROW_LOAD_CHAIN, which
 * cannot carry the trailing '.'.  The dot was handed to
 * build_postfix_value_chain, which folded the member offset onto the BASE
 * LOCAL's frame slot and DROPPED every '->' hop -- so `base->ptr->link.p' read
 * a word out of the local frame instead of dereferencing the chain.  When the
 * folded offset was large enough it landed in the return-address band (the
 * stack checker caught THAT); otherwise it read the wrong value silently.
 *
 * The single-arrow spelling `p->emb.field' has always worked (its own arm at
 * the top of build_arrow_access); the fix gives the SAME routing -- through the
 * uniform lvalue walker, exactly what the STORE (`...=x') and address-of
 * (`&...') spellings of this shape already use -- to a later hop.
 *
 * TWO locals so the frame is >= 8 and the .prev offset lands in the RA band,
 * the way uundo's did.  FGX-only oracle.  20 + 22 = 42. */

struct rec {
    struct { struct rec *n; struct rec *p; } link;   /* LINK(): n@0, p@4 */
    int tag;
};
struct node { struct rec *ptr; };

struct rec ra, rb;
struct node nd;

int main(void)
{
    struct node *base = &nd;    /* local 1 (pointer) */
    struct rec  *got;           /* local 2 -> FRAMESIZE >= 8 */
    int r = 0;

    rb.tag = 44;
    ra.link.p = &rb;            /* ra.link.prev -> rb */
    nd.ptr = &ra;

    got = base->ptr->link.p;    /* the fixed shape: arrow, arrow-to-emb, .field */
    if (got == &rb)     r += 20;
    if (got->tag == 44) r += 22;   /* the value is actually reachable */
    return r;                       /* 42 */
}

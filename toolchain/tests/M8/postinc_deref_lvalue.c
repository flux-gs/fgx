/* postinc_deref_lvalue: postfix '++' of a parenthesized DEREF lvalue --
 * `(*vp)++` (tcsh sh.exp `i |= 1, (*vp)++`, vp a `Char **`).  This bumps the
 * POINTEE `*vp` -- a Char* cursor -- not vp itself (distinct from `*vp++`,
 * which bumps vp).  build_postfix_value_chain left the trailing '++' unconsumed
 * ("expected ';'").  Routed to N_LV_INCDEC_E: the pointee's address IS vp's own
 * value, so emit lands it in _fcc_ptr and RMWs the Char* word in place, bumping
 * by ptr_stride (1 for a Char*) and preserving the stored bank.  Value here is
 * discarded (as in sh.exp).  K&R A.7.3.4 (postfix), A.7.4.3 ('*').  -> 42. */
char  str[5];
char *cursor;

int
main()
{
    char **vp;               /* local -> N_DEREF_FAST path */
    int    r;

    str[0] = 10; str[1] = 12; str[2] = 20; str[3] = 99;
    cursor = str;            /* cursor -> &str[0] */
    vp = &cursor;            /* *vp == cursor (a Char*) */

    r  = **vp;               /* *cursor = str[0] = 10          */
    (*vp)++;                 /* cursor advances to &str[1] (discarded) */
    r += **vp;               /* str[1] = 12               -> 22 */
    (*vp)++;                 /* cursor -> &str[2]              */
    r += **vp;               /* str[2] = 20               -> 42 */

    return r;                /* 42 */
}

/* paren_member_postinc: `(p->field)++;` as a statement -- postfix '++' binds
 * looser than '->', so the wrapper parens strip to `p->field++` (tcsh sh.exec
 * `(sp->word)++;`).  The paren-lvalue stmt arm only handled `(*ptr)++`; an
 * IDENT-led inner now splices the wrapper ')' and re-dispatches.  The `(*p)++`
 * deref-RMW path (which must NOT strip -- `(*p)++` != `*p++`) is unchanged.
 * -> 42. */
struct s { char *word; };

int
main()
{
    char    buf[8];
    struct s  x;
    struct s *sp;
    char     *p;
    char    **cp;

    sp = &x;
    sp->word = buf;
    (sp->word)++;            /* pointer member postinc via parens: +1 */
    (sp->word)++;            /* +1 -> word == buf+2 */

    p = buf;
    cp = &p;
    (*cp)++;                 /* deref-RMW path (unchanged): p == buf+1 */

    return (int)(sp->word - buf)      /* 2 */
         + (int)(p - buf)             /* 1 */
         + 39;                        /* 2 + 1 + 39 == 42 */
}

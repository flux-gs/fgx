/* postinc_ptrptr_member: postfix '++' of a POINTER-TO-POINTER struct member,
 * old value dereferenced -- `*wp->fe++` (tcsh sh.func `strsave(*whyles->w_fe++)`,
 * w_fe a `Char **` = char ptr-ptr).  The member-incdec parse whitelist only
 * admitted depth-1 scalar pointers (char, int, void, long ptr), rejecting a
 * ptr-to-ptr member so the trailing '++' was left unconsumed ("expected ')'").
 * emit_member_incdec is already depth-agnostic -- ptr_stride is 4 for a ptr-ptr
 * and it RMWs the member in place
 * preserving the stored bank -- so broadening the gate to any non-struct/non-fn
 * pointer member is the whole fix.  K&R A.7.3.4 (postfix ++ yields OLD, then +1),
 * A.7.4.3 ('*').  -> 42. */
struct W { char **fe; };
struct W  w;
struct W *wp;
char     *tab[3];
char      x0 = 10, x1 = 12, x2 = 20;

/* helper derefs the passed char ptr in its own frame -- mirrors tcsh's
 * strsave(*whyles->w_fe++): the incremented pointer's OLD value is passed
 * as a far-pointer ARG, never re-dereffed through a local here. */
int
deref1(char *p)
{
    return *p;
}

int
main()
{
    int r;

    tab[0] = &x0; tab[1] = &x1; tab[2] = &x2;
    w.fe = tab;              /* fe -> &tab[0] */
    wp = &w;

    r  = deref1(*wp->fe++);  /* *tab[0]=x0=10 ; fe now -> &tab[1] */
    r += deref1(*wp->fe++);  /* *tab[1]=x1=12 ; fe now -> &tab[2]  (=22) */
    r += deref1(*wp->fe);    /* *tab[2]=x2=20  (no ++)             (=42) */

    return r;                /* 42 */
}

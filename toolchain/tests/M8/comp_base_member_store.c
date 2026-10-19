/* comp_base_member_store: a computed (function-call) base for '->' is a
 * postfix expression, and K&R A.7.3.3 (p.164) makes its '->' result an
 * lvalue -- so `f(x)->member OP= rhs` is a valid compound store.  2.11BSD
 * /bin/sh xec.c hits this via the attrib macro:
 *   attrib(lookup(*com), exitval) == (lookup(*com)->namflg |= exitval).
 * Standard C; host cc validates directly.  -> 42. */
struct nam { struct nam *l, *r; char *id; int flg; };
struct nam nodes[4];
struct nam *lookup();
struct nam *lookup(k) int k; { return &nodes[k]; }

int
main()
{
    nodes[1].flg = 8;
    (lookup(1)->flg |= 32);         /* computed-base |= (attrib shape): 8|32=40 */
    (lookup(1)->flg += 2);          /* computed-base += (attrib shape): 40+2=42 */
    return lookup(1)->flg;          /* computed-base read: 42 */
}

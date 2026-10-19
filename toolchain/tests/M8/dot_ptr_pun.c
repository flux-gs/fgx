/* dot_ptr_pun: K&R 1st-ed global-member pun (A.7.3 p.164: a member name "had
 * to belong to the structure ... however ... this rule was not firmly
 * enforced") applied to '.' on a NON-struct pointer -- the 2.11BSD Bourne
 * shell's Lcheat idiom:
 *     union { int _cheat; };
 *     #define Lcheat(a)  ((a)._cheat)
 *     Lcheat(gchain) |= ARGMK;      ==   ((gchain)._cheat) |= 01;
 * '.' on a pointer aliases the pointer's OWN storage as an int (offset 0, no
 * deref -- K&R A.7.3.3 member-of-value + A.6.6 "a pointer may be converted to
 * an integral type ... the mapping function is implementation-dependent").
 * Bourne uses it to pack an ARGMK tag bit into a pointer.  Host cc (ANSI)
 * rejects the pun; the value is checked against the ANSI-equivalent int-alias
 * (*(int*)&p).  -> 42. */
struct cell { struct cell *next; int v; };
struct cell  node;
struct cell *p;
union { int _cheat; };

int
main()
{
    p = &node;
    ((p)._cheat) &= 0;          /* Lcheat store: clear the pointer's low int  */
    ((p)._cheat) |= 42;         /* Lcheat store: pack 42 into the low int     */
    return (int)p;              /* Rcheat read: (int)p == the low int == 42   */
}

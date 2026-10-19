/* field_init_null_paren: a NULL pointer constant as a struct pointer-field
 * initializer, allowing a grouping paren around a cast -- `((char*)0)`, the
 * 2.11BSD Bourne shell's NIL.  K&R A.6.6 (p.160): an integral constant 0,
 * optionally cast, is a null pointer.  fcc's skip_field_init_cast greedily ate
 * the grouping paren AND the 0, so the null wasn't recognized.  Also exercises
 * an array-name pointer-field init (decay, A.7.1).  '*' is ASCII 42.  -> 42. */
struct nn { struct nn *l; struct nn *r; char *id; };
char nm[] = "*x";
struct nn node = { ((char*)0), ((char*)0), nm };

int
main()
{
    char *p;

    if (node.l != 0) return 1;      /* NIL == ((char*)0) -> NULL */
    if (node.r != 0) return 2;
    p = node.id;                    /* array-name decay init */
    return p[0];                    /* '*' == 42 */
}

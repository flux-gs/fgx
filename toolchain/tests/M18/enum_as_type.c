/* enum_as_type: `enum TAG` used as a type in every position C allows, and
 * enumerator values as full constant expressions.
 *
 * Two separate gaps, both found porting 4.3BSD-Reno's VFS, which declares
 * `enum vtype v_type` as a struct member, takes `enum vtagtype` as a
 * parameter, and casts to enum types throughout.
 *
 *   1. An enumerator's value accepted only an int or char LITERAL.  C89 3.5.2.2
 *      requires an integer constant expression, so `A = 1 << 3`, `sizeof`, an
 *      earlier enumerator, and a conditional were all rejected.
 *   2. `enum TAG` was accepted as a type in only two positions -- a struct
 *      member and through a typedef.  As a local, as a file-scope variable, and
 *      as a K&R parameter declaration it was refused, because the predicates
 *      deciding "does a declaration start here" listed struct and union but not
 *      enum.  At file scope the cause was different and worth noting: `enum`
 *      was intercepted before the declaration path and always treated as a
 *      definition, so the parser demanded a semicolon where a declarator stood.
 *
 * The values are checked, not just the syntax: each position reads a value back
 * and the total is asserted, so an enumerator resolving to the wrong number
 * fails even though everything compiled.  -> 42.
 */

/* Enumerator values as constant expressions, including a reference to an
 * earlier enumerator in the same list. */
enum flags { F_SHIFT = 1 << 3, F_NEXT = F_SHIFT + 2, F_SIZE = sizeof(long),
             F_COND = (1 < 2) ? 4 : 99, F_NEG = -3 };

/* Compile-time proof, independent of anything running. */
char _sa_shift[F_SHIFT == 8  ? 1 : -1];
char _sa_next [F_NEXT  == 10 ? 1 : -1];
char _sa_size [F_SIZE  == 4  ? 1 : -1];
char _sa_cond [F_COND  == 4  ? 1 : -1];
char _sa_seq  [sizeof(enum flags) == 2 ? 1 : -1];

enum vtype { VNON, VREG, VDIR, VBLK, VCHR };

/* As a struct member -- the shape Reno's vnode uses. */
struct vnode { int v_flag; enum vtype v_type; int v_tag; };

/* As a file-scope variable: refused before, because the top-level parser
 * treated any `enum` as a definition. */
enum vtype g_type;

struct vnode g_vnode;

/* As a K&R parameter declaration -- how the borrowed sources spell it. */
static int
take_enum(t)
enum vtype t;
{
    return (int)t;
}

/* Through a pointer parameter. */
static int
take_enum_ptr(p)
enum vtype *p;
{
    return (int)*p;
}

int
main()
{
    enum vtype local;          /* as a local: refused before */
    int total;

    g_type          = VDIR;    /* 2 */
    g_vnode.v_type  = VCHR;    /* 4 */
    local           = VREG;    /* 1 */

    total  = take_enum(g_type);          /* 2 */
    total += take_enum(g_vnode.v_type);  /* 4 */
    total += take_enum_ptr(&local);      /* 1 */
    total += (int)(enum vtype)VBLK;      /* 3 -- cast to an enum type */
    /* 2 + 4 + 1 + 3 == 10 */

    total += F_SHIFT + F_NEXT + F_SIZE + F_COND + F_NEG;
    /* 10 + 8 + 10 + 4 + 4 + (-3) == 33 */

    return total + 9;                    /* 33 + 9 == 42 */
}

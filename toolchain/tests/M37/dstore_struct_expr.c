/* apple/fgx#281: a whole-struct assignment through a DEREFERENCED POINTER,
 * used as an EXPRESSION -- `(*p = src)'.  The statement `*p = src;' has always
 * worked (parse_stmt builds S_DSTORE_STRUCT_COPY) and so has the parenthesised
 * form with an OBJECT destination, `(other = src)'; only the deref destination
 * was missing from the expression layer, so the arm rewound to the rvalue path
 * and left the '=' orphaned ("expected ')'").
 *
 * 2.11BSD's fsck is where it surfaced: fsck.h defines
 *     #define zapino(x)  (*(x) = zino)
 * and pass1.c calls `zapino(dp);'.  The parens are the ordinary defensive ones
 * every function-like macro carries, so the shape is house style in ported K&R
 * sources rather than exotic.
 *
 * K&R A.7.17 admits it twice: simple assignment's operands may "both be
 * structures or unions of the same type", and "The type of an assignment
 * expression is that of its left operand, and the value is the value stored in
 * the left operand" -- an assignment expression has a type and a value
 * whatever its operands, so there is no statement-only class to belong to.
 * A.5 supplies the lvalue: "if E is an expression of pointer type, then *E is
 * an lvalue expression referring to the object to which E points."
 *
 * EVERY BYTE IS CHECKED, and the odd member count is deliberate: the failure
 * this guards against is a fall-through that stores TWO BYTES of the source's
 * ADDRESS instead of copying the object, which a one-member struct would not
 * distinguish from a correct copy.  `after' catches a copy that runs long.
 * Exits 42 iff all three land (14 + 14 + 14). */
struct three { int a; int b; int c; };

struct three zero;
struct three src;
struct three dst;
struct three after;

int
main()
{
    struct three *p;
    int r = 0;

    src.a = 0x1111; src.b = 0x2222; src.c = 0x3333;
    after.a = 0x7777; after.b = 0x7777; after.c = 0x7777;

    p = &dst;
    (*p = src);                         /* the #281 shape, value discarded */
    if (dst.a == 0x1111 && dst.b == 0x2222 && dst.c == 0x3333 &&
        after.a == 0x7777 && after.b == 0x7777 && after.c == 0x7777)
        r += 14;

    (*(p) = zero);                      /* upstream's spelling: parens on p too */
    if (dst.a == 0 && dst.b == 0 && dst.c == 0 &&
        after.a == 0x7777)
        r += 14;

    /* In a comma expression, where the assignment is unambiguously an
     * expression rather than a statement wearing parentheses. */
    if (((*p = src), dst.b) == 0x2222 && dst.c == 0x3333)
        r += 14;

    return r;
}

/* paren_assign_base: a parenthesized ASSIGNMENT used as the base of `->`.
 *
 * K&R A.7.17: "The type of an assignment expression is that of its left
 * operand, and the value is the value stored in the left operand after the
 * assignment has taken place."  The result is a VALUE, not an lvalue.  So in
 *
 *     (t->link[1] = p)->link[2] = t;
 *
 * the `->link[2]` applies to the VALUE p, i.e. the address is p + 16 -- there
 * is no second dereference.
 *
 * fcc emitted one anyway.  The assignment node carried its TYPE (LT_STRUCT_PTR)
 * but not its struct_id, so the following `->` failed the strict field lookup,
 * fell into the K&R 1st-ed global-member pun -- where the TOKEN drives deref,
 * and `->` means deref -- and computed (*p) + 16.
 *
 * Found via tcsh: sh.set.c's rleft/rright AVL rotate macros use exactly this
 * shape, so `balance()` wrote a tree link 16 bytes into whatever p->vec pointed
 * at.  In practice that was the 8-byte `Char **vec` array from set(), so the
 * write ran past it onto the kernel heap guard -> "HEAP CORRUPT: bad guard in
 * Kfree".  -> 42.
 */
struct v {
    char        **vec;          /* offset 0  -- what the bogus deref loaded */
    char         *name;         /* offset 4  */
    struct v     *link[3];      /* offset 8  -- link[2] is at +16 */
    int           bal;          /* offset 20 */
};

struct v a, b;

int
main()
{
    struct v *t, *p;

    t = &a;
    p = &b;
    t->vec = 0;
    t->link[1] = 0;
    p->link[2] = 0;

    (t->link[1] = p)->link[2] = t;

    /* The assignment itself must still have happened... */
    if (t->link[1] != p)
        return 1;
    /* ...and the chained store must have landed on p, not on *p. */
    if (p->link[2] != t)
        return 2;
    /* p->vec must be untouched: the old codegen dereferenced it as the base. */
    if (t->vec != 0)
        return 3;
    return 42;
}

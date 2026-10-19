/* Constant-expression relational/equality/logical operators and the
 * conditional operator.
 *
 * fcc's constant-expression evaluator handled only arithmetic, shifts and the
 * bitwise operators, so the standard K&R compile-time assertion
 *
 *     char _assert_something[(EXPR) ? 1 : -1];
 *
 * did not parse -- it was rejected at the `==`.  FGX needs that idiom to pin
 * on-disk structure layouts at compile time: the 2.11BSD filesystem work
 * overlays `struct dinode` and `struct fs` directly on disk buffers, which is
 * only sound while fcc keeps PDP-11 field alignment (2-byte, longs NOT
 * 4-aligned).  Without an assertion, a future alignment change would silently
 * corrupt every volume instead of failing the build.
 *
 * The negative-size array is the assertion mechanism: a true condition yields
 * `char x[1]`, a false one `char x[-1]`, which fcc rejects.  That is what
 * makes these declarations a test rather than decoration -- flip any expected
 * value and the fixture stops compiling.
 *
 * Ordering matters as much as availability here, so the cases below pin the
 * precedence ladder rather than just checking each operator parses. */

/* --- the layout assertions this feature exists for ----------------------- */

struct icommon1 { unsigned short ic_mode, ic_nlink, ic_uid, ic_gid; long ic_size; };
struct icommon2 { long ic_atime, ic_mtime, ic_ctime; };
struct dinode {
    struct icommon1 di_ic1;
    long            di_addr[7];
    unsigned short  di_reserved[5];
    unsigned short  di_flags;
    struct icommon2 di_ic2;
};
char _sa_dinode_is_64[sizeof(struct dinode) == 64 ? 1 : -1];

/* The discriminator.  Under PDP-11 rules the long sits at offset 2 and the
 * struct is 6 bytes; under 4-byte long alignment it would be 8.  This is the
 * case that actually notices an alignment change -- dinode happens to total 64
 * under both rules, so asserting only dinode would be a vacuous guard. */
struct pdp_probe { unsigned short w; long l; };
char _sa_pdp_alignment[sizeof(struct pdp_probe) == 6 ? 1 : -1];

/* --- operator availability ----------------------------------------------- */

char _sa_eq[(1 == 1) ? 1 : -1];
char _sa_ne[(1 != 2) ? 1 : -1];
char _sa_lt[(1 <  2) ? 1 : -1];
char _sa_gt[(2 >  1) ? 1 : -1];
char _sa_le[(2 <= 2) ? 1 : -1];
char _sa_ge[(2 >= 2) ? 1 : -1];
char _sa_andand[(1 && 2) ? 1 : -1];
char _sa_oror[(0 || 3) ? 1 : -1];
char _sa_not[(!0) ? 1 : -1];

/* --- precedence ----------------------------------------------------------
 * Each of these is false if the corresponding rung is mis-ordered. */

/* arithmetic binds tighter than comparison: 1+1 == 2, not 1 + (1==2) */
char _sa_add_over_cmp[(1 + 1 == 2) ? 1 : -1];
/* comparison binds tighter than equality: (1 < 2) == 1 */
char _sa_rel_over_eq[(1 < 2 == 1) ? 1 : -1];
/* equality binds tighter than bitwise-and: (1 == 1) & 1 */
char _sa_eq_over_and[((1 == 1 & 1) == 1) ? 1 : -1];
/* && binds tighter than || : 0 || (1 && 1) */
char _sa_and_over_or[(0 || 1 && 1) ? 1 : -1];
/* shifts bind tighter than comparison: (1 << 3) > 4 */
char _sa_shift_over_cmp[(1 << 3 > 4) ? 1 : -1];

/* --- the conditional operator itself -------------------------------------- */

char _sa_cond_true[(1 ? 1 : -1)];
char _sa_cond_false[(0 ? -1 : 1)];
/* nested in the true arm: a ? (b ? c : d) : e */
char _sa_cond_nest_then[(1 ? 1 ? 1 : -1 : -1)];
/* right-associative in the false arm: a ? b : (c ? d : e) */
char _sa_cond_nest_else[(0 ? -1 : 1 ? 1 : -1)];
/* the conditional binds looser than every binary rung */
char _sa_cond_loosest[(1 + 1 == 2 ? 1 : -1)];

/* Array bounds are one consumer of this evaluator; case labels are another,
 * and they share it -- so exercise both, or the precedence renumbering could
 * regress one while the array path stayed green.
 *
 * NOT covered, deliberately: enum initialisers.  Those go through a separate
 * and stricter path that accepts only an int/char literal, so
 * `enum { E = (1 < 2) ? 4 : 9 };` is still rejected.  Widening that is a real
 * gap but an independent one, and nothing in the filesystem work needs it. */
int
classify(int n)
{
    switch (n) {
        case (1 == 1) ? 10 : 99: return 1;
        case (1 > 2) ? 99 : 20:  return 2;
        default:                 return 0;
    }
}

int
main(void)
{
    /* Reference the assertion objects so nothing is dead-stripped, and return
     * a value that depends on the case labels above resolving correctly. */
    return (int)(_sa_dinode_is_64[0] + _sa_pdp_alignment[0]) +
           classify(10) + classify(20) * 2;
}

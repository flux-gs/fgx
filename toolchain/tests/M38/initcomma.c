/* A BRACE INITIALIZER LIST MAY END WITH A COMMA.
 *
 * K&R 2nd ed A.8.7, p.179, gives both productions and says why the second
 * exists: "A list may end with a comma, a nicety for neat formatting."
 *
 *     initializer:
 *         assignment-expression
 *         { initializer-list }
 *         { initializer-list , }
 *
 * fcc accepted `{ "na" }' -- a SHORT element, zero-filling the rest -- and
 * `{ "ro", 0, 1 }', but not `{ "na", }': the comma was consumed, the loop
 * moved to the next field, and the closing brace arrived where a value should
 * be.  The error came out as "expected integer constant in initializer" at
 * the NEXT element's line, which is a diagnostic pointing several lines past
 * its cause.
 *
 * 2.11BSD's mount(8) is the case that found it.  mntopts.h's MOPT_NOAUTO is
 * literally `{ "na", }, { "auto", }' and every mount option table in the
 * system expands it.
 *
 * BOTH LEVELS ARE COVERED, because they are two separate loops in the parser
 * and the outer one had the same hole: `elems' ends with a trailing comma
 * after its last ELEMENT, and each of the short elements ends with one after
 * its last FIELD.  A fix to one would leave the other.
 */

struct opt {
    char *o_name;
    int   o_inverse;
    int   o_flag;
};

static struct opt elems[] = {
    { "ro",   0, 1 },
    { "na", },
    { "auto", },
    { 0 },
};

/* And the plain-array forms, which share neither loop but share the rule. */
static int ints[] = { 1, 2, 3, };
static char *strs[] = { "a", "b", };

main()
{
    /* 1 + 1 + 0 + 3 + 1 = 6 ... the arithmetic is only here to keep every
     * element referenced; what the fixture asserts is that it COMPILES and
     * that the goldens do not move for anything that was already legal. */
    return elems[0].o_flag + elems[1].o_inverse + elems[2].o_flag
         + ints[2] + (strs[1][0] == 'b');
}

/* Adjacent string literals are ONE literal -- K&R 2nd ed A.2.6 (p.156),
 * apple/fgx#158.
 *
 *   "Adjacent string literals are concatenated into a single string.  After any
 *    concatenation, a null byte \0 is appended to the string so that programs
 *    that scan the string can find its end."
 *
 * THE VALUES ARE THE TEST, not the fact that it parses.  A parser that accepted
 * the second literal and threw it away would compile this file perfectly and
 * still be broken, so every case indexes PAST the first fragment.
 *
 * A BITMASK, not a sum: a wrong sum says only that something is wrong, and each
 * of these cases fails for a different reason.  Each bit names its own case, so
 * an exit code of 20 says "four-in-a-row and the escape boundary", which is a
 * diagnosis rather than a starting point.
 *
 *   1   the plain pair.
 *   2   the terminator.  A.2.6 says ONE null byte, appended AFTER the join --
 *       not one per fragment, which would truncate the string at the seam.
 *   4   a MACRO-produced fragment.  Concatenation is translation phase 6 and
 *       macro expansion is phase 4, so this must join AFTER expansion -- the
 *       half a fix in the raw scanner would silently miss.
 *   8   four in a row: the natural implementation is a loop, and an `if` passes
 *       the two-literal case.
 *  16   AN ESCAPE AT THE SEAM, and this is the case A.2.6's wording demands.
 *  32   Concatenation joins the DECODED characters -- each literal is
 *  64   "initialized with the given characters" first -- so "\1" "2" is the two
 *       bytes 01 and '2'.  An implementation that spliced the SOURCE TEXT and
 *       decoded afterwards would read \12 as one octal escape and produce the
 *       single byte 012, with the '2' swallowed.  Both readings compile.
 *
 * 42 = every case correct.
 */
#define TAIL "!"

int main()
{
    char *p;
    char *q;
    char *r;
    char *e;
    int bad;

    p = "abc" "def";
    q = "hi" TAIL;
    r = "a" "b" "c" "d";
    e = "\1" "2";

    bad = 0;
    if (p[3] != 'd') bad = bad + 1;
    if (p[6] != 0)   bad = bad + 2;
    if (q[2] != '!') bad = bad + 4;
    if (r[3] != 'd') bad = bad + 8;
    if (e[0] != 1)   bad = bad + 16;
    if (e[1] != '2') bad = bad + 32;
    if (e[2] != 0)   bad = bad + 64;

    if (bad != 0) return bad;
    return 42;
}

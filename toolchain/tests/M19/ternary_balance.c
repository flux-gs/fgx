/* K&R A.7.16: "If the second and third operands are arithmetic, the usual
 * arithmetic conversions are performed to bring them to a common type, and
 * that type is the type of the result."
 *
 * So `c ? f : 1' is float whichever arm runs, and `c ? big : 1' is long.  The
 * cases that discriminate are the ones where the arm TAKEN has a different
 * type from the other: a compiler that types the whole expression by one arm
 * reads the other arm's value as the wrong width.  Both orders are here, for
 * float and for long.  Exits 42 iff all four agree. */
int one = 1;
float f = 2.5;
long big = 70000L;

int
main()
{
    float r;
    long l;
    int ok;

    ok = 0;
    r = one ? f : 1;            /* float arm taken */
    if (r == 2.5)
        ok += 10;
    r = one ? 1 : f;            /* int arm taken, converted to float */
    if (r == 1.0)
        ok += 10;
    l = one ? big : 1;          /* long arm taken */
    if (l == 70000L)
        ok += 11;
    l = one ? 1 : big;          /* int arm taken, converted to long */
    if (l == 1)
        ok += 11;
    return ok;
}

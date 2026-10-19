/* K&R A.7.8: "each operand must be integral, and is subject to integral the
 * promotions.  The type of the result is that of the promoted left operand."
 * The usual arithmetic conversions do not apply to a shift, so the count
 * neither widens the result nor lends it its signedness.
 *
 * fcc balanced a shift like any other binary operator.  `i << 1L' was a LONG,
 * so 0x4000 << 2L was 65536 rather than the int 0; and `n >> s' with an
 * unsigned count was treated as unsigned and shifted LOGICALLY, so -16 >> 2u
 * came out 16380.  A.7.8 leaves a negative left operand's right shift
 * implementation-defined; fcc's choice for a signed int is arithmetic, and the
 * count's type must not change that choice -- `n >> s' has to agree with
 * `n >> 2'.  Exits 42 iff all hold. */
int
main()
{
    int i = 1, n = -16;
    long c = 3L, l = -32L;
    unsigned s = 2, u = 0x8000;
    int sc = 4;
    int big = 0x4000;
    long c2 = 2L;
    int ok = 0;

    if ((big << c2) == 0)
        ok += 10;                   /* an int result: 0x4000 << 2 wraps to 0 */
    if ((i << c) == 8)
        ok += 10;                   /* a long count still shifts */
    if ((n >> s) == (n >> 2) && (n >> s) == -4)
        ok += 11;                   /* the count's unsignedness is not the result's */
    if ((u >> sc) == 0x0800 && (l >> s) == -8L)
        ok += 11;                   /* an unsigned left stays logical; a long stays long */
    return ok;
}

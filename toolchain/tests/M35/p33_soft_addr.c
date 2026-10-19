/* M35 / bank-0 stack campaign 1.3: the ADDRESS-TAKING half of a soft frame.
 *
 * p33_recurse proved soft frames for SCALARS.  fib and fact hold plain ints and
 * take no addresses, so between them they exercised exactly ONE of the lowering
 * paths that touch a local -- emit_slot_op.  Every other path still addressed
 * the frame as BANK 0, and a bank-0 address inside a soft function reads
 * whatever bank 0 happens to hold, which is the hardware stack itself.  Wrong
 * data, no trap, no crash.
 *
 * This fixture drives the paths p33_recurse cannot reach, all inside functions
 * the p33_soft_addr.softscc sidecar marks soft:
 *
 *   &local                  emit_addr_of_local      bank must be DBR, not 0
 *   char array elem store   emit_store_local_elem   es == 1
 *   long array elem store   emit_store_local_elem   es == 4
 *   2D partial decay        emit_air_tail           row-pointer bank mint
 *
 * Each function recurses, so a soft frame is genuinely allocated and released
 * per activation rather than the outermost one being read by accident.
 *
 * WHY THE STRUCT CASE CARRIES THE ADDRESS CHECK.  An array is only ever reached
 * through its minted base, so a base with the wrong bank is SELF-CONSISTENT:
 * the writes and the reads land on the same wrong address and the arithmetic
 * still comes out right.  The first draft of this fixture had only arrays, and
 * it passed with emit_addr_of_local's soft arm deliberately mutated off --
 * measured, not assumed.  A struct is the one local with TWO independent paths
 * to the same storage: `s.f = v` lowers to the soft slot op, `&s` goes through
 * the address mint.  Writing by field and reading through the pointer makes the
 * two paths agree or the fixture fails, which is the actual claim.
 *
 * Portable C: clang returns 42. */

struct pt {
    int x, y;
};

int
psum(struct pt *p)                     /* reads the caller's soft frame */
{
    return p->x + p->y;
}

int
addr_of(int depth)
{
    int v;
    int *p;

    v = depth;
    p = &v;                            /* &local -> emit_addr_of_local */
    if (depth > 0)
        *p = *p + addr_of(depth - 1);
    return *p;                         /* sum 0..depth */
}

long
elems(int n)
{
    char cs[4];
    long ls[2];
    int i;

    for (i = 0; i < 4; i++)
        cs[i] = (char)(n + i);         /* es == 1 element store */
    ls[0] = (long)cs[3];               /* es == 4 element store */
    ls[1] = ls[0] + 1;
    if (n > 0)
        return ls[1] + elems(n - 1);
    return ls[1];
}

int
rowsum(int n)
{
    int m[2][3];
    int *row;
    int i, s;

    for (i = 0; i < 3; i++) {
        m[0][i] = i;
        m[1][i] = i + n;
    }
    row = m[1];                        /* 2D partial decay -> emit_air_tail */
    s = row[0] + row[1] + row[2];
    if (n > 0)
        s = s + rowsum(n - 1);
    return s;
}

int
crosspath(int n)
{
    struct pt s;
    int viafield, viaptr;

    s.x = n;                           /* field store  -> soft slot op */
    s.y = n + 1;
    viafield = s.x + s.y;              /* field load   -> soft slot op */
    viaptr = psum(&s);                 /* &local       -> address mint */
    if (viafield != viaptr)            /* the two paths MUST agree */
        return -1;
    if (n > 0) {
        viaptr = crosspath(n - 1);
        if (viaptr < 0)
            return -1;
        viafield = viafield + viaptr;
    }
    return viafield;
}

int
main(void)
{
    if (addr_of(3) != 6)    return 1;  /* 3+2+1+0 */
    if (elems(2) != 15L)    return 2;  /* 6 + 5 + 4 */
    if (rowsum(2) != 18)    return 3;  /* 9 + 6 + 3 */
    if (crosspath(2) != 9)  return 4;  /* 5 + 3 + 1 */
    return 42;
}

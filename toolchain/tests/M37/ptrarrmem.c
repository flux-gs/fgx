/* ptrarrmem.c -- storing through a struct's ARRAY-OF-POINTERS member.
 *
 * THE STATEMENT SPELLING WAS AN ARTIFICIAL REJECT.  `s.pa[i] = p;` died
 * "expected '='" while `p->pa[i] = p2;`, `pa[i] = p;` on a plain array, and
 * the whole READ side all worked -- the apple/fgx#155 twin-arm pattern, where
 * the expression layer had built N_STORE_PTRARR_ELEM correctly all along and
 * only the statement arm was missing.  Found writing the UFS inode hash
 * (1.11a): `ihashtbl[i].ih_chain[0] = (struct inode *)&ihashtbl[i];`.
 *
 * IT ASSERTS VALUES, NOT THAT IT COMPILES, and that is the point of the whole
 * fixture.  The statement arm it now routes past would have stored through
 * emit_fpr_deref_store_word -- TWO bytes -- so a pointer element would have
 * kept its offset and LOST ITS BANK.  A test that only compiled would pass
 * against that, and the failure would surface much later as a far pointer that
 * reads plausible garbage from bank zero.  apple/fgx#153b is the standing
 * lesson: a parse fix's test must assert values.
 *
 * So every case below writes a pointer in and reads the POINTED-AT DATUM back.
 */

struct node {
    int          nv;
    struct node *nxt;
};

struct table {
    int          before;            /* catches a store one slot low */
    struct node *slot[4];
    int          after;             /* ...and one slot high */
};

static struct table  tbl;
static struct table  arr[2];
static struct node   a, b, c;

int
main()
{
    struct table *tp;
    int           i;

    a.nv = 11; b.nv = 22; c.nv = 33;
    tbl.before = 111; tbl.after = 222;

    /* 1. THE SHAPE THAT WAS REJECTED: dot, pointer-array member, constant
     *    index, address-of RHS. */
    tbl.slot[0] = &a;
    if (tbl.slot[0]->nv != 11)          return (1);

    /* 2. A CAST RHS, which is how the UFS hash writes its own head in. */
    tbl.slot[1] = (struct node *)&b;
    if (tbl.slot[1]->nv != 22)          return (2);

    /* 3. A VARIABLE index -- the constant-index case can be folded and this
     *    one cannot, so they are different emitter paths. */
    i = 2;
    tbl.slot[i] = &c;
    if (tbl.slot[2]->nv != 33)          return (3);

    /* 4. THE NEIGHBOURS ARE UNTOUCHED.  A store that scaled the index by two
     *    instead of four lands inside the array but on the wrong slot; a store
     *    that missed the member offset lands on `before`.  Both are silent
     *    without this. */
    if (tbl.before != 111)              return (4);
    if (tbl.after != 222)               return (5);
    if (tbl.slot[3] != (struct node *)0) return (6);

    /* 5. NULL back in, and read back as null.  A 2-byte store would leave a
     *    stale bank behind and this is where that shows. */
    tbl.slot[0] = (struct node *)0;
    if (tbl.slot[0] != (struct node *)0) return (7);
    if (tbl.slot[1]->nv != 22)          return (8);

    /* 6. THROUGH AN ARRAY OF STRUCTS -- `arr[i].slot[j] = p`, the exact
     *    spelling the UFS hash initialiser uses, and the TWIN this fixture
     *    found: fixing the `s.pa[i]` arm left this one still rejected.
     *
     *    READ BACK THROUGH A POINTER, not as `arr[0].slot[0]->nv`.  That
     *    RVALUE spelling is a THIRD gap and is still rejected -- filed as
     *    apple/fgx#170 with its reproduction.  Reading through tp exercises
     *    the arrow arm, which was always correct, and still proves what this
     *    case is here to prove: that the store through the array-of-structs
     *    spelling landed the whole four-byte pointer, bank included. */
    arr[0].slot[0] = &a;
    arr[1].slot[3] = &c;
    tp = &arr[0];
    if (tp->slot[0]->nv != 11)          return (9);
    if (tp->slot[3] != (struct node *)0) return (11);
    tp = &arr[1];
    if (tp->slot[3]->nv != 33)          return (10);
    if (tp->slot[0] != (struct node *)0) return (12);

    /* 7. AND THE ARROW SPELLING STILL WORKS, which is the arm that was already
     *    right -- a fix that broke it would be a poor trade. */
    tp = &tbl;
    tp->slot[3] = &a;
    if (tp->slot[3]->nv != 11)          return (13);
    if (tbl.slot[3]->nv != 11)          return (14);

    /* 8. THE READ SIDE, unchanged and re-checked: a pointer read out of the
     *    member and used as a base. */
    a.nxt = &b;
    tbl.slot[0] = &a;
    if (tbl.slot[0]->nxt->nv != 22)     return (15);

    return (42);
}

/* selfchain.c -- a circular list head that points at ITSELF.
 *
 * `tbl[i].chain[0] = (struct x *)&tbl[i];` with a VARIABLE index, storing the
 * address of the very element being written.  This is how a BSD hash table is
 * initialised -- an empty circular chain is a head whose both links are the
 * head -- and it is the shape UFS 1.11a's ufs_ihashinit uses.
 *
 * ptrarrmem.c covers the array-of-structs pointer-array store, but its RHS is
 * always a DIFFERENT object (&a, &b).  Here the RHS is derived from the same
 * subscript as the destination, so a store that evaluated the index twice, or
 * evaluated the RHS after advancing a pointer, lands somewhere else entirely.
 */

struct node { int v; };

struct head {
    struct node *chain[2];
    int          tag;
};

static struct head tbl[4];

int
main()
{
    int          i;
    struct head *hp;

    for (i = 0; i < 4; i++) {
        tbl[i].tag = 100 + i;
        tbl[i].chain[0] = (struct node *)&tbl[i];
        tbl[i].chain[1] = (struct node *)&tbl[i];
    }

    /* READ BACK THROUGH A POINTER.  `tbl[i].chain[0]` as an RVALUE is a gap
     * of its own (apple/fgx#171) -- the arrow-rooted spelling works and the
     * array-rooted one does not -- so the checks go through hp, which is what
     * the kernel's own hash walk does anyway. */
    for (i = 0; i < 4; i++) {
        hp = &tbl[i];
        if (hp->chain[0] != (struct node *)hp) return (1 + i);
        if (hp->chain[1] != (struct node *)hp) return (5 + i);
        if (hp->tag != 100 + i)                return (9 + i);
    }

    /* And the heads are DISTINCT -- a store that ignored the index would make
     * them all equal and still pass a self-comparison. */
    {
        struct head *h0;
        struct head *h1;
        h0 = &tbl[0]; h1 = &tbl[1];
        if (h0->chain[0] == h1->chain[0]) return (13);
        h0 = &tbl[2]; h1 = &tbl[3];
        if (h0->chain[0] == h1->chain[0]) return (14);
    }

    return (42);
}

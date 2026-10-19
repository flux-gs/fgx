/* charincdec.c -- `++'/`--' on a CHAR leaf in VALUE position.
 * apple/fgx#215 (it REJECTED) and apple/fgx#216 (three other routes ACCEPTED
 * it and miscompiled it).
 *
 * ONE DEFECT, TWO SYMPTOMS, ONE FIX.  Every route ends in
 * emit_incdec_at_fcc_ptr, which did a 16-BIT WORD RMW.  On a one-byte object
 * that reads the neighbour into the result, writes it back from a copy taken
 * three instructions earlier, and at 0xFF carries INTO it.  The single-hop
 * spellings were rejected outright, so the defect looked closed; the dot,
 * array-element and chain routes were not, and compiled the broken word RMW.
 * The fix is an 8-bit arm in that one function.
 *
 * K&R A.7.4.1 (p.165) puts no type bound on the operand: "The object referred
 * to by the lvalue operand of a prefix ++ is incremented.  The value is the
 * new value of the operand, and is an lvalue expression."  A.4.2 (p.157) is
 * what makes the yielded value 0..255 rather than sign-extended: "Other
 * quantities may be stored into char variables, but the available range of
 * values, and especially whether the value is signed, is implementation-
 * dependent."  fcc's choice is that plain char behaves UNSIGNED -- every char
 * load in emit.c zero-extends (`:1686', `:5131', `:450', `:632') -- so the
 * incdec value form must agree with the loads it sits beside.  That is why the
 * borrow cases below assert 255 and not -1.
 *
 * THE VALUE ALONE PROVES ALMOST NOTHING HERE, which is the trap that let #216
 * live: a 16-bit RMW leaves the RIGHT value in the member for small numbers,
 * and the previous probe missed the defect precisely because it asserted the
 * counter and not its neighbour.  So every case does all of:
 *
 *   (a) asserts the YIELDED value, which is what the word RMW got wrong first
 *       -- it yielded (neighbour << 8) | value;
 *   (b) asserts the STORED byte afterwards; and
 *   (c) asserts BOTH NEIGHBOURS, which is the only thing that sees the stale
 *       write-back and the carry.
 *
 * Cases 7-10 are the wrap and the borrow, and they are not decoration.  A
 * byte-store path that forgets to mask the PREFIX result stores the right byte
 * and leaves the right neighbour, so only `++c.b == 0' at 0xFF catches it --
 * SEP #$20 truncates A for the store but preserves the hidden high byte, so
 * the wrapped 0x100 is back in A after REP #$20.  Postfix at wrap is NOT
 * equivalent cover: its result comes from the saved copy, which was masked at
 * load.
 *
 * Oracle 42 = 14 cases * 3.
 */

struct S { char hi; char b; char lo; };
struct Q { struct S S; char qguard; };

/* a char that is the LAST byte of its struct: there is no neighbouring MEMBER
 * to assert, so the guard sits in the enclosing struct where the layout is
 * decided rather than in a separate global whose address is the linker's. */
struct L { int pad; char last; };
struct O { struct L inner; char guard; };

struct S  gs;
struct Q  gq;
struct O  go;
char      carr[4];
unsigned char gu;
long      gl;

clear()
{
    gs.hi = 0x41; gs.b = 4; gs.lo = 0x43;
    gq.S.hi = 0x51; gq.S.b = 4; gq.S.lo = 0x53; gq.qguard = 0x54;
    go.inner.pad = 0x6162; go.inner.last = 4; go.guard = 0x63;
    carr[0] = 0x71; carr[1] = 4; carr[2] = 0x73; carr[3] = 0x74;
    gu = 4;
}

main()
{
    struct S *p;
    struct Q *qp;
    int r, v, i;
    long lv;

    r = 0;
    p = &gs;
    qp = &gq;

    /* ---- 1: THE apple/fgx#215 SHAPE, verbatim from 2.11BSD ttyinput:
     * `} else if (tp->t_rocount++ == 0)'.  Postfix arrow, char member, in
     * value position.  It yields the OLD value and stores the new one. */
    clear();
    gs.b = 0;
    v = 0;
    if (p->b++ == 0)
        v = 1;
    if (v == 1 && gs.b == 1 && gs.hi == 0x41 && gs.lo == 0x43)
        r += 3;

    /* ---- 2: postfix DOT.  Same leaf, the other single-hop spelling. */
    clear();
    v = gs.b++;
    if (v == 4 && gs.b == 5 && gs.hi == 0x41 && gs.lo == 0x43)
        r += 3;

    /* ---- 3: prefix ARROW -- yields the NEW value, not the old. */
    clear();
    v = ++p->b;
    if (v == 5 && gs.b == 5 && gs.hi == 0x41 && gs.lo == 0x43)
        r += 3;

    /* ---- 4: prefix DOT.  apple/fgx#216: this ACCEPTED before the fix and
     * emitted the word RMW, so it yielded (0x41 << 8) | 5 == 0x4105. */
    clear();
    v = ++gs.b;
    if (v == 5 && gs.b == 5 && gs.hi == 0x41 && gs.lo == 0x43)
        r += 3;

    /* ---- 5: CHAR ARRAY ELEMENT, apple/fgx#216's second route.  `i' is a
     * variable so the subscript cannot fold to a constant address. */
    clear();
    i = 1;
    v = ++carr[i];
    if (v == 5 && carr[1] == 5 &&
        carr[0] == 0x71 && carr[2] == 0x73 && carr[3] == 0x74)
        r += 3;

    /* ---- 6: ARROW CHAIN INTO A CHAR LEAF, apple/fgx#216's third route --
     * two hops, so the walker rather than the fixed-shape member node. */
    clear();
    v = ++qp->S.b;
    if (v == 5 && gq.S.b == 5 &&
        gq.S.hi == 0x51 && gq.S.lo == 0x53 && gq.qguard == 0x54)
        r += 3;

    /* ---- 7: PREFIX AT THE WRAP.  0xFF + 1 must YIELD 0.  This is the one
     * case that catches a byte-store path with no POST-add mask: the stored
     * byte is 0 and both neighbours are clean either way, and only the value
     * differs (0x100 vs 0).  Nothing else here can see it. */
    clear();
    gs.b = 0xFF;
    v = 1;
    if (++gs.b == 0)
        v = 0;
    if (v == 0 && gs.b == 0 && gs.hi == 0x41 && gs.lo == 0x43)
        r += 3;

    /* ---- 8: POSTFIX AT THE WRAP.  Yields the OLD 255 and stores 0.  THE
     * NEIGHBOUR ASSERTION IS THE POINT: under the word RMW the carry out of
     * 0xFF incremented gs.lo (the high byte of the word at &gs.b) from 0x43
     * to 0x44, which no assertion on gs.b could ever see. */
    clear();
    gs.b = 0xFF;
    v = gs.b++;
    if (v == 255 && gs.b == 0 && gs.hi == 0x41 && gs.lo == 0x43)
        r += 3;

    /* ---- 9: PREFIX BORROW.  0 - 1 must yield 255, NOT -1: fcc zero-extends
     * every char load, so the incdec value form agrees with them (K&R A.4.2
     * leaves the signedness to the implementation).  A distinct path from the
     * carry -- SBC rather than ADC. */
    clear();
    gs.b = 0;
    v = --gs.b;
    if (v == 255 && gs.b == 255 && gs.hi == 0x41 && gs.lo == 0x43)
        r += 3;

    /* ---- 10: POSTFIX BORROW.  Yields 0, stores 255, and the borrow must not
     * decrement the neighbour. */
    clear();
    gs.b = 0;
    v = gs.b--;
    if (v == 0 && gs.b == 255 && gs.hi == 0x41 && gs.lo == 0x43)
        r += 3;

    /* ---- 11: A CHAR THAT IS THE LAST BYTE OF ITS STRUCT.  There is no
     * neighbouring member inside `inner', so a word store runs off the end of
     * the object; `guard' in the enclosing struct is what sees it. */
    clear();
    go.inner.last = 0xFF;
    v = go.inner.last++;
    if (v == 255 && go.inner.last == 0 &&
        go.guard == 0x63 && go.inner.pad == 0x6162)
        r += 3;

    /* ---- 12: UNSIGNED CHAR SPELLED EXPLICITLY, at the wrap, so the arm is
     * exercised on the type whose range the yielded value is supposed to
     * match rather than only on plain char. */
    clear();
    gu = 0xFF;
    v = gu++;
    if (v == 255 && gu == 0)
        r += 3;

    /* ---- 13: THE YIELD CONSUMED BY A WIDENING CONTEXT.  The value leaves
     * the arm as an int and is then widened to long, so a result carrying a
     * dirty high byte would survive into the wider type. */
    clear();
    gs.b = 0xFF;
    lv = (long)(gs.b++);
    if (lv == (long)255 && gs.b == 0 && gs.lo == 0x43)
        r += 3;

    /* ---- 14: THE NEIGHBOUR IS NOT MERELY UNCHANGED, IT IS NOT REWRITTEN.
     * The word RMW wrote the neighbour back from a copy read earlier, which a
     * single-threaded test cannot distinguish from leaving it alone -- so this
     * case changes the neighbour BETWEEN the read and the write by making the
     * incremented member the SECOND of two operations, and checks the first
     * one's effect survived. */
    clear();
    gs.b = 0x10;
    gs.lo = 0x20;
    v = ++gs.b;                       /* reads b, and under the defect lo too */
    gs.lo = 0x2A;                     /* change the neighbour after the read  */
    v = v + gs.b;
    if (v == 0x11 + 0x11 && gs.lo == 0x2A && gs.hi == 0x41)
        r += 3;

    return r;                          /* 14 * 3 == 42 */
}

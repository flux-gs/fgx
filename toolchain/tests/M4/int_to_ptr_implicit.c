/* The IMPLICIT sibling of int_to_ptr_databank: assigning a runtime int
 * EXPRESSION to a pointer must reconstitute into the DATA bank too, not bank 0.
 *
 * FIXED 2026-08-04 (third attempt).  apple/fgx#12, and #16 with it.
 *
 * WHAT DECIDED IT, after two attempts argued the wrong question.  Both earlier
 * attempts assumed fcc had to INVENT a rule for this construct, and neither
 * could make the invented rule coherent.  The answer was already written down
 * in the compiler 2.11BSD was built with, vendored at
 * examples/2.11BSD/usr/lib/ccom.  c01.c:244-266, the integer-to-pointer (ITP)
 * arm of `=`:
 *
 *     if ((cvn==ITP || cvn==LTP)
 *        && (p2->t.op!=CON || p2->c.value!=0)
 *        && (p2->t.op!=LCON || p2->l.lvalue!=0)) {
 *             werror("illegal combination of pointer and integer, op =");
 *             if (cvn==ITP)
 *                     cvn = leftc = 0;      // conversion CANCELLED
 *
 * and eight lines below, the CAST arm:
 *
 *     } else if (op==CAST) {
 *             if (cvn==ITP||cvn==PTI)
 *                     cvn = leftc = 0;      // IDENTICAL
 *
 * Two things follow.  (1) The real compiler DIAGNOSED this -- `werror`, a
 * warning -- so the construct was never invisible; PDP-11 programmers accepted
 * it because sizeof(int) == sizeof(char*) there and cancelling the conversion
 * is lossless.  The 2.11BSD source is not wrong, it is CORRECT FOR ITS TARGET.
 * (2) A cast and an implicit assignment emit IDENTICAL code.  There is no
 * semantic distinction between `p = i` and `p = (T*)i` in the language 2.11BSD
 * was written against, so fcc must emit the same for both.  On a PDP-11 "the
 * bits verbatim" IS the whole address; on FGX the int carries only the offset,
 * so the bank has to come from somewhere -- DBR for a runtime value, 0 for a
 * constant (K&R A.6.6 leaves the mapping to the implementation).
 *
 * THE HALF OF ccom's RULE THAT DOES NOT SURVIVE THE PORT.  "Cancel the
 * conversion, take the bits verbatim" silently carries a second guarantee on a
 * PDP-11: a RUNTIME integer zero IS the null pointer, because the bits are the
 * whole address.  Stamping DBR unconditionally breaks it -- a runtime zero
 * becomes DBR:0000, which fcc #6's bank-inclusive truth test reads as NON-null,
 * so every `if (p)` and NULL-terminated walk on it runs on.
 *
 * That is not hypothetical: it broke the boot on the first pass of this very
 * attempt.  2.11BSD sh hits it in its hottest path -- macro.c:86
 *
 *     v = ((c==0) ? cmdadr : (c<=dolc) ? dolv[c] : (dolg=0));
 *
 * assigns a runtime zero to a pointer for an unset positional parameter, and
 * getch() runs that for every `$` expansion.  The kernel booted fine and 23 of
 * 24 runtime tests died, because bsh is /bin/sh and the login shell.
 *
 * So the mapping is: offset 0 -> bank 0 (the null pointer), any other offset ->
 * the data bank.  It is applied by the _fcc_bank_for_int runtime helper rather
 * than inline, which also keeps each site the same 3 bytes as the LDA it
 * replaced.  A.6.6 leaves the mapping to the implementation; this is the choice
 * that makes the null pointer survive a runtime round-trip.
 *
 * A REJECTED ALTERNATIVE, recorded so it is not re-proposed: add the casts to
 * the vendored source (6 sites -- stak.c:77, blok.c:75, service.c:325/340, and
 * a `DOLPTR freeargs();` declaration for args.c:125 / xec.c:358) and lean on
 * the already-correct explicit-cast arm.  It was measured to work.  It is still
 * wrong: since ccom treats cast and implicit assignment as ONE construct,
 * adding casts would be editing the source to accommodate an fcc-only
 * divergence -- the exact work-around-the-toolchain anti-pattern.
 *
 * WHY THE FIRST TWO ATTEMPTS FAILED, and what changed:
 *
 *   1st -- converted walk_fpr WHOLESALE.  Too broad: walk_fpr is every
 *      value-to-pointer materialization (1512 sites in tcsh), mostly CARRIAGE
 *      (comparison operands, argument passing), not conversion.  It also could
 *      not have landed: the DBR read was a 9-byte SEP/PHB/PLA/REP island at
 *      every site and tcsh has 331 B of slack in 429,119 B, so it failed to
 *      PACK, with an error that said only "investigate".
 *
 *   2nd -- added a separate walk_fpr_conv entry point, and never wired it to a
 *      caller.  Dead code for a whole session while the RESUME recorded the
 *      return path as "converted".  The bank decision also lived in a sticky
 *      global (g_rhs_const_int) published at only two store arms and never
 *      reset, so most store paths never saw it.
 *
 *   3rd -- two changes.  (a) walk_expr() sets g_expr_const_int after EVERY
 *      walk, giving the bank bit exactly g_expr_type's lifetime, which the
 *      store lowerings already depend on; that covers all nine parse_stmt.c
 *      store arms and the return path at once, and it cannot go stale.
 *      (b) emit_fpr_from_a(k, BankSel) takes a MANDATORY bank with no default,
 *      so a materialization site that does not choose fails to build fcc.  That
 *      forcing property is what found the sites the first two attempts missed:
 *      four arms that hardcoded `LDA #0` and never consulted any gate at all
 *      (emit.c:1281, emit.c:1367, parse_stmt.c:1839, plus the call-argument
 *      path at parse_expr.c:1818, which launders bank 0 THROUGH an otherwise
 *      correct callee store).
 *
 * Gating walk_fpr on cast_operand_is_const(n) is what makes the wholesale
 * conversion unnecessary: the carriage cases are exactly the constant ones, so
 * `p == 0` and `f(NULL)` still take BANK_ZERO and emit byte-identical code.
 * Evidence it is surgical: exactly ONE golden of 549 changed, this one.
 *
 * The cost blocker is gone independently: _fcc_dbr (crt0-seeded; DBR is
 * invariant in FGX2 user code) replaced the SEP/PHB/PLA/REP island, making each
 * site 6 bytes CHEAPER than before the fix.
 *
 * WHAT #16 WAS.  sh's endstak() (stak.c:77) runs for every completed word and
 * does `stakbot = staktop = round(argp,BYTESPERWORD)`, where round() launders
 * through (int).  With bank 0 stamped, the shell's whole stak arena lived as a
 * phantom inside the kernel's bank-0 stack arena (`end EQU $3690`;
 * FGX_STK_ARENA is $2200-$B6FF).  Self-consistent at disjoint offsets until a
 * large `.` parse grew it into live stack pages and the shell overwrote its own
 * return stack mid-parse.  No fault, no message, no output: a 65816 write to
 * bank-0 RAM traps nothing.
 *
 * `base` arrives as a parameter so the int is a genuine RUNTIME value rather
 * than a foldable &g constant, which would legitimately take the literal arm.
 *
 * A CEILING TO KNOW: DBR-stamping is correct only for data-bank objects.  A
 * pointer laundered through int that refers to a SOFT-STACK local (frames live
 * in their own bank since the bank-0 campaign) reconstitutes wrongly under both
 * the old rule and the new one.  sh launders only arena/data pointers, so it is
 * out of scope here.
 *
 * One deliberate divergence from ccom: ccom exempts only a CON of value 0,
 * whereas cast_operand_is_const() exempts any integer constant expression, so
 * `(char*)-1` and `(char*)0xC000` keep bank 0.  That is the right
 * implementation-defined mapping for FGX -- a literal hardware address is a
 * bank-0 address -- and A.6.6 explicitly leaves the mapping to us.
 *
 * The host is NOT the oracle for this file: casting a pointer through `int` is
 * well-defined only where sizeof(int) == sizeof(void *), which is the 16-bit
 * model fcc targets and 2.11BSD was written for.  On a 64-bit host it truncates
 * and segfaults.  The oracle is the FGX runtime (tests/oracle.json), exactly as
 * for its explicit-cast sibling int_to_ptr_databank.c.
 */
int g;
int guard;
int dolg;
char *cmdadr;

/* The macro.c:86 shape, reduced: an assignment EXPRESSION yielding a RUNTIME
 * zero, reaching a pointer.  Not a compile-time constant, so it takes the
 * conversion path -- and the conversion must still produce a NULL.  This is the
 * case that broke the boot: the fixture below only tested the CONSTANT null
 * (`p = 0`), which passed throughout, so it could not catch what shipped. */
char *
pick(c)
int c;
{
    char *v;

    v = (c == 0) ? cmdadr : (dolg = 0);
    return v;
}

int *
bump(base)
int base;
{
    int *p;

    p = base + 0;            /* implicit int -> pointer, NO cast: the gap */
    return p;
}

int
main()
{
    int *p;
    int *q;

    guard = 0;
    p = &g;
    q = bump((int)p);
    *q = 42;                 /* a bank-0 reconstitution writes the wrong bank */
    if (g != 42)
        return 1;            /* stored somewhere that is not our data segment */

    /* NULL must still be bank 0, or the far-pointer truth test (fcc #6, which
     * compares bank AND offset) stops recognising it.  This is the case the
     * old unconditional `LDA #0` existed to protect, and it must survive. */
    p = 0;
    if (p)
        return 2;

    /* A RUNTIME zero must be NULL too.  Without this, `(dolg=0)` reconstitutes
     * as DBR:0000, which the bank-inclusive truth test reads as TRUE -- and
     * 2.11BSD sh dereferences it for every unset positional parameter. */
    dolg = 1;
    if (pick(9))
        return 3;
    if (pick(0) != cmdadr)
        return 4;            /* the non-zero arm must survive intact */

    /* ...and a runtime NON-zero must still reach the data bank, or a fix that
     * simply reverts everything to bank 0 would pass the two checks above. */
    guard = 0;
    q = bump((int)&guard);
    *q = 7;
    if (guard != 7)
        return 5;

    return 42;
}

/* dotvarincdec.c -- `gv.m++'/`gv.m--' in VALUE position on a struct VARIABLE
 * base.  apple/fgx#217.
 *
 * THE BASE'S VALUE WAS USED AS THE MEMBER'S ADDRESS.  emit_member_incdec
 * loaded the base with emit_load_local/emit_load_global, which is right for a
 * POINTER base -- a pointer's value IS the address -- and wrong for a struct
 * variable, whose address is `#name'.  So `clocks.system++' loaded the first
 * WORD OF THE STRUCT, added the member offset, and read-modify-wrote through
 * the result: a wild access at an address made out of the struct's own first
 * member.
 *
 * NOT A CHAR DEFECT.  It hit INT members identically and had nothing to do
 * with apple/fgx#215/#216; it was found by their fixture, whose postfix-dot
 * case failed while every pointer-base case passed.
 *
 * IT WAS LIVE IN SHIPPED CODE: src/userland/telnet/telnet.c:179 is
 *
 *     #define settimer(x)  clocks.x = clocks.system++
 *
 * over `struct { int system, echotoggle, ...; } clocks;' at six call sites, so
 * every telnet timer update wrote through an address equal to the timer count.
 *
 * THE PREFIX DOT SPELLING NEVER HAD IT, which is what made the defect
 * survivable for so long and is asserted here as a cross-check: `++gv.m'
 * builds an N_LV_INCDEC_E and goes through emit_lvalue_addr, which computes
 * the address properly.  Only the fixed-shape member node reached the broken
 * base load, so half the spellings of the same operation were correct.
 *
 * K&R A.7.3.2 (p.163) is what says the base is not a value here: "A postfix
 * expression followed by a dot . and an identifier is a postfix expression.
 * The first operand expression must be a structure or a union, and the
 * identifier must name a member of the structure or union.  The value is the
 * named member of the structure or union, and it is an lvalue if the first
 * expression is an lvalue."  The operand is the OBJECT, not a pointer to it.
 *
 * Oracle 42 = 14 cases * 3.
 */

struct I { int  hi; int  b; int  lo; };
struct C { char hi; char b; char lo; };
struct P { int  hi; char *p; int  lo; };
struct N { struct I inner; int guard; };

struct I gi;
struct C gc;
struct P gp;
struct N gn;
char     buf[8];

/* the telnet shape, verbatim in structure */
struct { int system, echotoggle, modenegotiated; } clocks;

clear()
{
    gi.hi = 0x41; gi.b = 4; gi.lo = 0x43;
    gc.hi = 0x41; gc.b = 4; gc.lo = 0x43;
    gp.hi = 0x41; gp.p = &buf[2]; gp.lo = 0x43;
    gn.inner.hi = 0x51; gn.inner.b = 4; gn.inner.lo = 0x53; gn.guard = 0x54;
    clocks.system = 7; clocks.echotoggle = 0; clocks.modenegotiated = 0;
}

main()
{
    struct I li;
    struct C lc;
    struct I *ip;
    struct C *cp;
    int r, v;

    r = 0;
    ip = &gi;
    cp = &gc;

    /* ---- 1: INT member, postfix ++ on a GLOBAL struct variable.  The
     * defect's centre: yields OLD, stores NEW, neighbours untouched. */
    clear();
    v = gi.b++;
    if (v == 4 && gi.b == 5 && gi.hi == 0x41 && gi.lo == 0x43)
        r += 3;

    /* ---- 2: INT member, postfix -- .  The decrement arm of the same node. */
    clear();
    v = gi.b--;
    if (v == 4 && gi.b == 3 && gi.hi == 0x41 && gi.lo == 0x43)
        r += 3;

    /* ---- 3: INT member, PREFIX ++ -- the spelling that was always correct,
     * kept as the cross-check that says the two agree now. */
    clear();
    v = ++gi.b;
    if (v == 5 && gi.b == 5 && gi.hi == 0x41 && gi.lo == 0x43)
        r += 3;

    /* ---- 4: CHAR member, postfix ++ on a global struct variable. */
    clear();
    v = gc.b++;
    if (v == 4 && gc.b == 5 && gc.hi == 0x41 && gc.lo == 0x43)
        r += 3;

    /* ---- 5: CHAR member, prefix ++ -- the walker route on the same base. */
    clear();
    v = ++gc.b;
    if (v == 5 && gc.b == 5 && gc.hi == 0x41 && gc.lo == 0x43)
        r += 3;

    /* ---- 6: A LOCAL STRUCT VARIABLE, int member.  A DISTINCT BASE PATH --
     * emit_addr_of_local rather than emit_addr_of_global, frame-relative and
     * bank-staged differently -- so a fix that only corrected globals passes
     * every case above and fails here. */
    li.hi = 0x61; li.b = 4; li.lo = 0x63;
    v = li.b++;
    if (v == 4 && li.b == 5 && li.hi == 0x61 && li.lo == 0x63)
        r += 3;

    /* ---- 7: a LOCAL struct variable, char member. */
    lc.hi = 0x71; lc.b = 4; lc.lo = 0x73;
    v = lc.b++;
    if (v == 4 && lc.b == 5 && lc.hi == 0x71 && lc.lo == 0x73)
        r += 3;

    /* ---- 8: THE TELNET SHAPE, `clocks.x = clocks.system++' -- the member
     * being read is also a member of the same struct, which is what the
     * broken base load made self-referential. */
    clear();
    clocks.echotoggle = clocks.system++;
    if (clocks.echotoggle == 7 && clocks.system == 8 &&
        clocks.modenegotiated == 0)
        r += 3;

    /* ---- 9: a POINTER base must still work -- this is the arm the old code
     * was right about, and a fix that swapped the two would break it. */
    clear();
    v = ip->b++;
    if (v == 4 && gi.b == 5 && gi.hi == 0x41 && gi.lo == 0x43)
        r += 3;

    /* ---- 10: the pointer base with a char member, same reason. */
    clear();
    v = cp->b++;
    if (v == 4 && gc.b == 5 && gc.hi == 0x41 && gc.lo == 0x43)
        r += 3;

    /* ---- 11: A POINTER MEMBER of a struct variable.  The stride is the
     * pointee size rather than 1, and the member's stored BANK byte must
     * survive the bump -- a base fix that left the bank staging wrong shows
     * up here as a pointer into the wrong bank. */
    clear();
    if (gp.p++ == &buf[2] && gp.p == &buf[3] &&
        gp.hi == 0x41 && gp.lo == 0x43)
        r += 3;

    /* ---- 12: dereference the bumped pointer, which is what proves the bank
     * byte is intact rather than merely that the offset moved. */
    clear();
    buf[2] = 0x21; buf[3] = 0x22;
    v = *gp.p++;
    if (v == 0x21 && *gp.p == 0x22 && gp.hi == 0x41)
        r += 3;

    /* ---- 13: A STRUCT INSIDE A STRUCT VARIABLE -- two hops to the leaf, so
     * the base offset and the member offset both contribute. */
    clear();
    v = gn.inner.b++;
    if (v == 4 && gn.inner.b == 5 &&
        gn.inner.hi == 0x51 && gn.inner.lo == 0x53 && gn.guard == 0x54)
        r += 3;

    /* ---- 14: THE WILD-WRITE CANARY.  Under the defect the RMW landed at an
     * address built from the struct's FIRST member, so setting that member to
     * the offset of a known object aimed the write at it.  buf is that object:
     * it must be untouched after an increment that, unfixed, would have
     * scribbled somewhere derived from gi.hi. */
    clear();
    buf[0] = 0x31; buf[1] = 0x32;
    gi.hi = 0x100;                     /* a plausible address, not a value */
    v = gi.b++;
    if (v == 4 && gi.b == 5 && gi.hi == 0x100 &&
        buf[0] == 0x31 && buf[1] == 0x32)
        r += 3;

    return r;                          /* 14 * 3 == 42 */
}

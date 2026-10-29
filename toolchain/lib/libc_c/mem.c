
void *memcpy(void *d, void *s, int n)
{
    __asm_p0 = (char *)d;
    __asm_p1 = (char *)s;
    __asm_w0 = n;
    /* [dp],Y long-indirect copy — d and s may live in different 64Ks, so
     * MVN is unusable (its bank bytes are compile-time immediates; the
     * banks here are runtime values — cf. emit.c emit_fpr_struct_copy).
     * 16-bit WORD loop (2 bytes/iter) with an odd-length tail byte: ~2x
     * the old per-byte M8 loop, still cross-bank-safe.  Y counts DOWN from
     * neven-2 (the fcc struct-copy idiom); n is a 16-bit int (<=32767) so
     * BPL terminates correctly. */
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDA __asm_p1",
        "STA c_strcmp_b",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "LDA __asm_p1+2",
        "STA c_strcmp_b+2",
        "REP #$20",
        "MX %00",
        "LDA __asm_w0",           /* A = n */
        "BEQ @mcp_done",          /* n == 0 -> nothing */
        "LSR",                    /* A = n>>1 (words); C = odd bit */
        "PHP",                    /* stash odd flag */
        "BEQ @mcp_tail",          /* n < 2 -> tail byte only */
        "ASL",                    /* A = neven */
        "DEC",
        "DEC",                    /* A = neven-2 */
        "TAY",                    /* Y = last word offset */
        "@mcp_wl",
        "LDA [c_strcmp_b],Y",     /* 16-bit word move */
        "STA [c_strcmp_a],Y",
        "DEY",
        "DEY",
        "BPL @mcp_wl",            /* until Y wraps negative */
        "@mcp_tail",
        "PLP",                    /* recover odd flag */
        "BCC @mcp_done",          /* even length -> done */
        "LDA __asm_w0",
        "DEC",
        "TAY",                    /* Y = n-1 (last byte) */
        "SEP #$20",
        "MX %10",
        "LDA [c_strcmp_b],Y",
        "STA [c_strcmp_a],Y",
        "REP #$20",
        "MX %00",
        "@mcp_done"
    );
    return d;
}

/* memset(3).  THE COUNT IS UNSIGNED, and the split below is what makes the
 * top half of the range reachable at all.
 *
 * The word loop indexes `[c_strcmp_a],Y' with Y walking DOWN to zero and ends
 * on `BPL', so it terminates on Y's SIGN.  That is correct and fast for any
 * count the 65816's index register can carry with bit 15 clear, and silently
 * does NOTHING for a count of 32770 or more: Y starts negative and the first
 * BPL falls through.  A caller zeroing 40 KB got a buffer that was never
 * touched and no diagnostic, which is how fsck(8) found it -- 2.11BSD's fsck
 * bzeroes its whole map arena in one call, and on a PDP-11 bzero is assembly
 * that takes the count as an unsigned word.
 *
 * The fix is a SPLIT rather than a new terminator, so the hot path keeps the
 * sign test and costs nothing: everything under the threshold takes exactly
 * the loop it always did.  _mgrow (malloc.c) splits an oversized sbrk the same
 * way for the same reason. */
static void *_memset1(void *p, int c, unsigned n);

void *memset(void *p, int c, unsigned n)
{
    if (n > 0x7FFEu) {
        (void)_memset1(p, c, (unsigned)0x7FFE);
        (void)_memset1((char *)p + 0x7FFE, c, n - 0x7FFEu);
        return p;
    }
    return _memset1(p, c, n);
}

static void *_memset1(void *p, int c, unsigned n)
{
    __asm_p0 = (char *)p;
    __asm_w0 = n;
    __asm_w1 = c;
    /* 16-bit WORD fill (2 bytes/iter) + odd tail byte; ~2x the old per-byte
     * loop.  Fill word = (c&0xff) replicated into both bytes.  c_strcmp_b is
     * free here (memset uses only c_strcmp_a) so it holds the byte scratch. */
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "REP #$20",
        "MX %00",
        "LDA __asm_w0",           /* A = n */
        "BEQ @mst_done",
        "LSR",                    /* words; C = odd */
        "PHP",
        "BEQ @mst_tail",          /* n < 2 */
        "ASL",
        "DEC",
        "DEC",                    /* A = neven-2 */
        "TAY",
        "LDA __asm_w1",           /* build replicated fill word */
        "AND #$00FF",
        "STA c_strcmp_b",
        "XBA",                    /* A = cc00 */
        "ORA c_strcmp_b",         /* A = cccc */
        "@mst_wl",
        "STA [c_strcmp_a],Y",
        "DEY",
        "DEY",
        "BPL @mst_wl",
        "@mst_tail",
        "PLP",
        "BCC @mst_done",
        "LDA __asm_w0",
        "DEC",
        "TAY",                    /* Y = n-1 */
        "SEP #$20",
        "MX %10",
        "LDA __asm_w1",
        "STA [c_strcmp_a],Y",
        "REP #$20",
        "MX %00",
        "@mst_done"
    );
    return p;
}

/* bcopy: BSD arg order (src, dst, len), overlap-safe (4.3BSD contract).
 * A 16-bit word at a time through [dp],Y, as memcpy does, in the direction
 * an overlap needs: up when dst is below src, down when it is above, and
 * either way when the two are in different banks.  Every word is read
 * before the store that could overwrite it, and the odd byte goes at the
 * end the copy has not yet reached -- last going up, first going down.
 * memcpy's own loop runs down and takes its odd byte last, which an
 * overlapping copy one byte up would read after overwriting it, so it is
 * not used here.  n <= 0 copies nothing. */
void bcopy(void *s, void *d, int n)
{
    __asm_p0 = (char *)d;
    __asm_p1 = (char *)s;
    __asm_w0 = n;
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDA __asm_p1",
        "STA c_strcmp_b",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "LDA __asm_p1+2",
        "STA c_strcmp_b+2",
        "CMP c_strcmp_a+2",       /* Z: same bank */
        "REP #$20",
        "MX %00",
        "BNE @bc_up",             /* different banks: no overlap */
        "LDA c_strcmp_a",
        "CMP c_strcmp_b",
        "BEQ @bc_done",           /* the same bytes */
        "BCS @bc_down",           /* dst above src */
        "@bc_up",
        "LDA __asm_w0",
        "BMI @bc_done",
        "AND #$FFFE",
        "STA __asm_w1",           /* the even count: the words' end */
        "BEQ @bc_utail",
        "LDY #0",
        "@bc_uw",
        "LDA [c_strcmp_b],Y",
        "STA [c_strcmp_a],Y",
        "INY",
        "INY",
        "CPY __asm_w1",
        "BCC @bc_uw",
        "@bc_utail",
        "LDA __asm_w0",
        "LSR",
        "BCC @bc_done",           /* even: no odd byte */
        "LDY __asm_w1",
        "SEP #$20",
        "MX %10",
        "LDA [c_strcmp_b],Y",
        "STA [c_strcmp_a],Y",
        "REP #$20",
        "MX %00",
        "BRA @bc_done",
        "@bc_down",
        "LDA __asm_w0",
        "BMI @bc_done",
        "LSR",
        "BCC @bc_dw0",            /* even: no odd byte */
        "LDA __asm_w0",
        "DEC",
        "TAY",                    /* Y = n-1, the odd byte */
        "SEP #$20",
        "MX %10",
        "LDA [c_strcmp_b],Y",
        "STA [c_strcmp_a],Y",
        "REP #$20",
        "MX %00",
        "@bc_dw0",
        "LDA __asm_w0",
        "AND #$FFFE",
        "BEQ @bc_done",
        "DEC",
        "DEC",
        "TAY",                    /* Y = the last word */
        "@bc_dw",
        "LDA [c_strcmp_b],Y",
        "STA [c_strcmp_a],Y",
        "DEY",
        "DEY",
        "BPL @bc_dw",
        "@bc_done"
    );
}

/* ANSI memmove: bcopy's overlap-safe copy with the ANSI argument order
 * and the dest return (frotz dumb_input's line editing). */
void *memmove(void *d, void *s, int n)
{
    bcopy(s, d, n);
    return d;
}


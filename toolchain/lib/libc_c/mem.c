
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
 * BOTH arms are its own loops now.  The dst<src arm used to delegate to
 * memcpy "the forward loop" -- true of the old per-byte M8 loop, FALSE
 * since the word-loop rewrite: memcpy's DEY/DEY/BPL idiom copies TOP-
 * DOWN, which is exactly the unsafe direction for a dst<src overlap.
 * frotz's libcadds fixture caught it on target: memmove(ov, ov+2, 4)
 * re-read its own fresh stores and doubled the tail.  An ascending byte
 * loop is slower than the word move, but bcopy's callers are the
 * overlap-prone ones by nature; non-overlap bulk copies use memcpy. */
void bcopy(void *s, void *d, int n)
{
    char *sp = (char *)s;
    char *dp = (char *)d;
    int i;

    if ((unsigned long)dp < (unsigned long)sp) {
        for (i = 0; i < n; i++)
            dp[i] = sp[i];
    } else if (dp != sp) {
        for (i = n - 1; i >= 0; i--)
            dp[i] = sp[i];
    }
}

/* ANSI memmove: bcopy's overlap-safe copy with the ANSI argument order
 * and the dest return (frotz dumb_input's line editing). */
void *memmove(void *d, void *s, int n)
{
    bcopy(s, d, n);
    return d;
}


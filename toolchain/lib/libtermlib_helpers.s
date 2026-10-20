;==============================================================================
; libtermlib_helpers.s - hand-asm termcap primitives (_tc_getstr/_tc_getnum/
; _tc_getflag), EXTRACTED from libc.s (shared-pile onboarding, 2026-07-17).
;
; libtermlib.c's tget* adapters near-JSR these from INLINE __asm (fcc passes
; them through verbatim), so they MUST be co-resident with the termlib pile.
; When they lived in libc.s the termlib pile could only link inside the libc
; segment — which forced every termlib-using tool's libc segment to diverge
; from the canonical shared pile (key mismatch -> per-tool private copies).
; Now the pair {libtermlib_helpers.s, libtermlib.s} travels together in the
; per-tool LIBS segment (seg3 / an elvis code bank) and seg2 stays canonical.
;
; The tc_* cap TABLES stay in libc_data.s (the seg1 frozen prefix); these
; helpers read them DBR-relative, which works from any code segment.
;==============================================================================
;==============================================================================
; vi-port slice 4: termcap shim (baked "fgx" entry).
;
; Three table-lookup primitives plus a no-op tgetent.  The shim does NOT
; ship tgoto / tputs — applications that need formatted cursor-motion
; sequences should call the kernel's VT102-aware Con_Write directly or
; format the escape themselves.  Slice 6 (vi port) decides whether to
; pull in a tgoto port from 2.11BSD or replace the call sites with an
; FGX-native cursor primitive.
;
; All cap names are 2-char codes.  Returned strings are libc-bank
; pointers and stable for the binary's lifetime (no copy into caller's
; `area` buffer — termcap callers may keep these directly).
;
; Supported caps (vt100/vt102-class for the IIgs SHR console):
;   strings   cm cl ce up do le nd so se
;   numbers   co (80)  li (24)
;   flags     am (auto-margin) bs (backspace)
;
; Anything else returns "not found" (tgetstr → 0, tgetnum → $FFFF,
; tgetflag → C=0).
;==============================================================================

;------------------------------------------------------------------------------
; tgetstr - look up string cap.  LIBC_DP_LP0 = 2-char cap-name long ptr
; (bank-aware; the c_tgetstr adapter fills it from the arg's far ptr so the
; name reads from its real bank — the string pool may be in the code seg under
; --data-segment or the data seg under --far-calls).  Returns: C=1 + A =
; cap-string offset (in the data bank, where tc_* live) on hit; C=0 + A=0 miss.
;------------------------------------------------------------------------------
_tc_getstr         MX      %00
                LDA     _tcStrTbl              ; the entry tgetent selected
                STA     LIBC_DP_DST              ; walk pointer (tc_str_table in DBR/data bank)
                SEP     #$20
                MX      %10
                ; Pre-load the 2 cap chars (low-ASCII normalized) into
                ; pf_tmpByte/pf_tmpByte+1.  Merlin's ASC sets bit 7; the
                ; caller might pass either form, so normalize.  Read the name via
                ; the bank-aware long ptr (code seg or data seg).
                LDY     #0
                LDA     [LIBC_DP_LP0],Y
                AND     #$7F
                STA     pf_tmpByte               ; cap[0]
                INY
                LDA     [LIBC_DP_LP0],Y
                AND     #$7F
                STA     pf_tmpByte+1             ; cap[1]
                REP     #$20
                MX      %00
@tgs_L          ; *(LIBC_DP_DST) → 2 cap chars; +2 → 16-bit ptr; entries
                ; terminated by 2 NUL bytes.
                SEP     #$20
                MX      %10
                LDY     #0
                LDA     (LIBC_DP_DST),Y
                AND     #$7F
                BEQ     @tgs_miss                ; first byte 0 → sentinel
                CMP     pf_tmpByte
                BNE     @tgs_next
                INY
                LDA     (LIBC_DP_DST),Y
                AND     #$7F
                CMP     pf_tmpByte+1
                BEQ     @tgs_hit
@tgs_next       REP     #$20
                MX      %00
                LDA     LIBC_DP_DST
                CLC
                ADC     #4                       ; entry size: 2 name + 2 ptr
                STA     LIBC_DP_DST
                BRA     @tgs_L
@tgs_hit        REP     #$20
                MX      %00
                LDY     #2
                LDA     (LIBC_DP_DST),Y          ; the value-ptr field
                SEC
                RTS
@tgs_miss       REP     #$20
                MX      %00
                LDA     #0
                CLC
                RTS

;------------------------------------------------------------------------------
; tgetnum - look up numeric cap.  LIBC_DP_LP0 = 2-char cap-name long ptr
; (bank-aware; filled by the c_tgetnum adapter).
; Returns: C=1 + A = number on hit; C=0 + A = $FFFF on miss (-1 in
; termcap convention).
;------------------------------------------------------------------------------
_tc_getnum         MX      %00
                LDA     _tcNumTbl              ; the entry tgetent selected
                STA     LIBC_DP_DST
                SEP     #$20
                MX      %10
                LDY     #0
                LDA     [LIBC_DP_LP0],Y
                AND     #$7F
                STA     pf_tmpByte
                INY
                LDA     [LIBC_DP_LP0],Y
                AND     #$7F
                STA     pf_tmpByte+1
                REP     #$20
                MX      %00
@tgn_L          SEP     #$20
                MX      %10
                LDY     #0
                LDA     (LIBC_DP_DST),Y
                AND     #$7F
                BEQ     @tgn_miss
                CMP     pf_tmpByte
                BNE     @tgn_next
                INY
                LDA     (LIBC_DP_DST),Y
                AND     #$7F
                CMP     pf_tmpByte+1
                BEQ     @tgn_hit
@tgn_next       REP     #$20
                MX      %00
                LDA     LIBC_DP_DST
                CLC
                ADC     #4
                STA     LIBC_DP_DST
                BRA     @tgn_L
@tgn_hit        REP     #$20
                MX      %00
                LDY     #2
                LDA     (LIBC_DP_DST),Y
                SEC
                RTS
@tgn_miss       REP     #$20
                MX      %00
                LDA     #$FFFF
                CLC
                RTS

;------------------------------------------------------------------------------
; tgetflag - look up boolean cap.  LIBC_DP_LP0 = 2-char cap-name long ptr
; (bank-aware; filled by the c_tgetflag adapter).
; Returns: C=1 + A=1 if flag is set; C=0 + A=0 otherwise.  (Anything
; not in the flag table is "not set", which is the termcap convention.)
;------------------------------------------------------------------------------
_tc_getflag        MX      %00
                LDA     _tcFlagTbl              ; the entry tgetent selected
                STA     LIBC_DP_DST
                SEP     #$20
                MX      %10
                LDY     #0
                LDA     [LIBC_DP_LP0],Y
                AND     #$7F
                STA     pf_tmpByte
                INY
                LDA     [LIBC_DP_LP0],Y
                AND     #$7F
                STA     pf_tmpByte+1
@tgf_L          LDY     #0
                LDA     (LIBC_DP_DST),Y
                AND     #$7F
                BEQ     @tgf_miss
                CMP     pf_tmpByte
                BNE     @tgf_next
                INY
                LDA     (LIBC_DP_DST),Y
                AND     #$7F
                CMP     pf_tmpByte+1
                BEQ     @tgf_hit
@tgf_next       REP     #$20
                MX      %00
                LDA     LIBC_DP_DST
                CLC
                ADC     #2                       ; flag-entry size: 2 name only
                STA     LIBC_DP_DST
                SEP     #$20
                MX      %10
                BRA     @tgf_L
@tgf_hit        REP     #$20
                MX      %00
                LDA     #1
                SEC
                RTS
@tgf_miss       REP     #$20
                MX      %00
                LDA     #0
                CLC
                RTS



;------------------------------------------------------------------------------
; _tc_setent - point the three lookup tables at an entry.  A = 0 for the IIgs
; console, nonzero for the remote ansi/vt102 entry (apple/fgx#147).
;
; Called from tgetent(), which does the name matching in C where strcmp lives.
; The STRING table is shared: both entries speak the same vt102 sequences, and
; only the margin flag and the default row count differ.
;
; MX %00.  Clobbers A.
;------------------------------------------------------------------------------
_tc_setent      MX      %00
                LDX     #tc_str_table            ; shared by both entries
                STX     _tcStrTbl
                AND     #$00FF
                BEQ     @tcs_console
                LDX     #tc_ansi_num_table
                STX     _tcNumTbl
                LDX     #tc_ansi_flag_table
                STX     _tcFlagTbl
                RTS
@tcs_console    LDX     #tc_num_table
                STX     _tcNumTbl
                LDX     #tc_flag_table
                STX     _tcFlagTbl
                RTS

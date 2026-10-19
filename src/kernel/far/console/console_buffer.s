;==============================================================================
; console_buffer.s - ring-buffer internals.
;
; Internal helpers (not exposed):
;   _Con_RingOffset(A=logical_row) -> A = byte offset into CharBuf (row*80)
;   _Con_ClearRingRow(A=logical_row) -> fills CharBuf[row*80..+80] with $20
;
; Scratch usage:
;   _conTmp0     (word): working row offset
;==============================================================================

;------------------------------------------------------------------------------
; _Con_LogicalRowFromVp - A (16-bit) = vpRow (0..CON_VIS_ROWS-1).
; Returns A (16-bit) = logical ring row (0..CON_BUF_ROWS-1).
;------------------------------------------------------------------------------
_Con_LogicalRowFromVp
                CLC
                ADC    |CON_VT_STATE+VT_TOP_ROW
                CMP    |CON_VT_STATE+VT_BUF_ROWS
                BCC     @lrv_done
                SBC    |CON_VT_STATE+VT_BUF_ROWS
@lrv_done       RTS

;------------------------------------------------------------------------------
; _Con_RingOffset - A = logical row (0..CON_BUF_ROWS-1).
; Returns A = byte offset from CharBuf (= row * 80).
; Caller responsible for bounds-checking / modulo.
; Preserves X, all DP scratches. Clobbers Y.
; Uses stack-relative addressing to avoid aliasing _conTmp0 with scroll callers.
;------------------------------------------------------------------------------
_Con_RingOffset
                PHA                         ; save row on stack (row*80 = row*5 << 4)
                ASL                         ; A = row * 2
                ASL                         ; A = row * 4
                CLC
                ADC     1,S                 ; A = row*4 + row = row*5
                ASL                         ; * 10
                ASL                         ; * 20
                ASL                         ; * 40
                ASL                         ; * 80
                TAY                         ; Y = row * 80
                PLA                         ; pop saved row (discard, restores SP)
                TYA                         ; A = row * 80
                RTS

;------------------------------------------------------------------------------
; _Con_CopyRingRow - A = source logical row, X = destination logical row.
; Copies the row's four per-cell arrays (CHARBUF, ATTRBUF, FGBUF, BGBUF, at
; $0000/$2000/$4000/$6000 in the console bank), so a scroll moves the cells
; with the pixels.  The rows are distinct, so the copy never overlaps.
; _DBRK after the MVN for the reason _Con_ClearRingRow gives.  Clobbers A, X,
; Y; preserves the DP scratches.
;------------------------------------------------------------------------------
_Con_CopyRingRow
                PHX
                JSR     _Con_RingOffset     ; A = source offset (preserves X)
                PLX
                PHA                         ; source offset
                TXA
                JSR     _Con_RingOffset
                PHA                         ; destination offset
                LDA     #0                  ; array base
@ccr_loop       PHA                         ; 1,S base, 3,S dst, 5,S src
                CLC
                ADC     5,S
                TAX                         ; X = source cell
                LDA     1,S
                CLC
                ADC     3,S
                TAY                         ; Y = destination cell
                LDA     _Con_RowBytesM2
                INC                         ; count - 1 for the whole row
_kcm023         MVN     $03,$03
                _DBRK                       ; MVN left DBR = console bank
                PLA
                CLC
                ADC     #$2000              ; the next array
                CMP     #$8000
                BCC     @ccr_loop
                PLA                         ; drop the two offsets
                PLA
                RTS

;------------------------------------------------------------------------------
; _Con_ClearRingRow - A = logical row.  Resets all four per-cell arrays for
; that row to their default-blank state:
;   CHARBUF[row*80..+80] = $20 (space)
;   ATTRBUF[row*80..+80] = $00 (no flags)
;   FGBUF  [row*80..+80] = $01 (default fg slot 1)
;   BGBUF  [row*80..+80] = $00 (default bg slot 0)
; Used when auto-scroll introduces a blank row at the bottom.
;
; Pattern (×4): write first byte directly with STAL CON_*BUF,X, then MVN
; bytes 1..79 from byte 0.  X stays at cell_offset across the four blocks
; (we save it on the stack since _conTmp0/1 are reserved for callers).
;
; _DBRK after EVERY MVN, not just the last: MVN leaves DBR = the destination
; bank (the console bank), and the next block reads its count with
; `LDA _Con_RowBytesM2` -- absolute, so DBR-relative.  Without the restore that
; read lands in the console bank at the same offset (inside CHARBUF, i.e.
; $2020 = 8224 once the buffer holds spaces) and the MVN smears the fill value
; across every following buffer.  See the note in console_vthandler.s.
;------------------------------------------------------------------------------
_Con_ClearRingRow
                JSR     _Con_RingOffset     ; A = row * 80
                TAX                         ; X = cell offset
                ; --- CHARBUF -> $20 ---
                SEP     #$20
                LDA     #$20
_kcb001         STAL    CON_CHARBUF,X
                REP     #$20
                PHX                         ; save cell offset
                TXA
                INC
                TAY                         ; Y = src+1
                LDA     _Con_RowBytesM2     ; count - 1
_kcm009         MVN     $03,$03             ; CHARBUF[X+1..+79] = CHARBUF[X]
                _DBRK                       ; MVN left DBR = console bank
                PLX
                ; --- ATTRBUF -> 0 ---
                SEP     #$20
                LDA     #0
_kcb002         STAL    CON_ATTRBUF,X
                REP     #$20
                PHX
                TXA
                CLC
                ADC     #$2000              ; src = ATTRBUF base + cell offset
                TAY                         ; Y = src (temporary)
                INY                         ; Y = dst = src + 1
                PHA
                PLX                         ; X = src
                LDA     _Con_RowBytesM2
_kcm010         MVN     $03,$03
                _DBRK                       ; MVN left DBR = console bank
                PLX
                ; --- FGBUF -> 1 ---
                SEP     #$20
                LDA     #1
_kcb003         STAL    CON_FGBUF,X
                REP     #$20
                PHX
                TXA
                CLC
                ADC     #$4000              ; src = FGBUF base + cell offset
                TAY
                INY
                PHA
                PLX
                LDA     _Con_RowBytesM2
_kcm011         MVN     $03,$03
                _DBRK                       ; MVN left DBR = console bank
                PLX
                ; --- BGBUF -> 0 ---
                SEP     #$20
                LDA     #0
_kcb004         STAL    CON_BGBUF,X
                REP     #$20
                TXA
                CLC
                ADC     #$6000              ; src = BGBUF base + cell offset
                TAY
                INY
                PHA
                PLX
                LDA     _Con_RowBytesM2
_kcm012         MVN     $03,$03
                ; Restore DBR = kernel-bank (MVN leaves DBR = $03)
                SEP     #$20
                _DBRK
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Con_FillAttrBuf - boot-time init of the per-cell attribute arrays.
;   CON_ATTRBUF  -> 0       (no flags set; B/I/U/G cleared)
;   CON_FGBUF    -> _conFg  (caller-set per-mode default fg palette idx)
;   CON_BGBUF    -> _conBg  (caller-set per-mode default bg palette idx)
;
; Uses long addressing + intra-bank-$03 MVN; safe to call anytime.
;------------------------------------------------------------------------------
_Con_FillAttrBuf
                SEP     #$20
                ; ATTRBUF -> 0
                LDA     #0
_kcb005         STAL    CON_ATTRBUF
                REP     #$30
                LDX     #$2000              ; src = $032000 (ATTRBUF byte 0)
                LDY     #$2001              ; dst = $032001
                LDA     #7998               ; 8000 - 2
_kcm013         MVN     $03,$03
                ; FGBUF -> VT_FG.  _DBRK FIRST: MVN left DBR on $03, and the
                ; read below is DBR-relative.  As a direct-page cell this was
                ; bank-immune; as a far-bank static it is not.
                SEP     #$20
                _DBRK
                LDA    |CON_VT_STATE+VT_FG
_kcb006         STAL    CON_FGBUF
                REP     #$30
                LDX     #$4000              ; src = $034000 (FGBUF byte 0)
                LDY     #$4001
                LDA     #7998
_kcm014         MVN     $03,$03
                ; BGBUF -> VT_BG.  _DBRK first, same reason as above.
                SEP     #$20
                _DBRK
                LDA    |CON_VT_STATE+VT_BG
_kcb007         STAL    CON_BGBUF
                REP     #$30
                LDX     #$6000              ; src = $036000 (BGBUF byte 0)
                LDY     #$6001
                LDA     #7998
_kcm015         MVN     $03,$03
                ; Restore DBR = kernel-bank (MVN clobbered it)
                SEP     #$20
                _DBRK
                REP     #$20
                RTS

;==============================================================================
; END console_buffer.s
;==============================================================================

;==============================================================================
; console_render.s - optimized CharBuf -> SHR renderer.
;
; Public:
;   Con_RenderRow    A = vpRow (0..24). Paint one row from CharBuf into SHR.
;   Con_RenderAll    Paint all 25 visible rows.
;
; Uses CON_PREEXP_REG_BASE / CON_PREEXP_BOLD_BASE variants (bank $04) selected
; per cell by AttrBuf B bit + fg/bg nibble (possibly I-swapped), and 8 unrolled
; [_conFontPtr],Y indirect-long stores per char. Per-row cost
; ~6 ms at 2.8 MHz (under Phase 1 target of 8 ms).
;
; _Con_RenderCell reads AttrBuf[cbOffset] to select PreExpFont variant via
; _Con_RegularVariantBaseTbl or _Con_BoldVariantBaseTbl, then reads glyph data through the
; 3-byte DP long pointer _conFontPtr ($E8).
;==============================================================================

_Con_rrRow      EQU     _conScratch0        ; vpRow, then logical row
_Con_rrCbIdx    EQU     _conScratch1        ; running CharBuf byte offset
_Con_rrScreen   EQU     _conScratch2        ; running SHR byte offset
_Con_rrCol      EQU     _conScratch3        ; column counter (byte)

;------------------------------------------------------------------------------
; Con_RenderRow - public dispatcher.  Routes to the mode's row renderer
; via _conMode.CM_ScbModeByte (bit 7 set = 640).
;
; A = vpRow.  MX %00.  Tail-calls (JMP) into the chosen renderer so its
; RTS returns to our caller.
;------------------------------------------------------------------------------
                MX      %00
Con_RenderRow
                PHA                             ; save vpRow BEFORE the guard clobbers A
                LDA    |CON_VT_STATE+VT_RENDER_STATE
                AND     #$00FF
                CMP     #$0002
                BCC     @crr_go                 ; state < 2: render
                BNE     @crr_skip               ; 3: a task owns the screen
                PLA                             ; 2: the flush draws it
                JMP     _Con_MarkDirty
@crr_skip       PLA                             ; rebalance stack, drop vpRow
                RTS
@crr_go         PLA
                BIT    |_conBackendOn           ; a module's renderer? (console_backend.s)
                BMI     @crr_be
                JMP     _Con_RenderRow_640
@crr_be         ; The back-end gets the ring row and the top row with the
                ; viewport row, so it never reads the VT state.
                PHA
                JSR     _Con_LogicalRowFromVp   ; A = ring row
                TAX
                LDY    |CON_VT_STATE+VT_TOP_ROW
                PLA                             ; A = vpRow
_Con_HkRenderRow JSL    $000000                 ; operand written by Con_SetBackend
                RTS

;------------------------------------------------------------------------------
; _Con_RenderRow_640 - A = vpRow (0..CON_VIS_ROWS-1).
;------------------------------------------------------------------------------
_Con_RenderRow_640
                STA     _Con_rrRow          ; save vpRow
                CLC
                ADC    |CON_VT_STATE+VT_TOP_ROW
                CMP    |CON_VT_STATE+VT_BUF_ROWS
                BCC     @rr_noWrap
                SBC    |CON_VT_STATE+VT_BUF_ROWS
@rr_noWrap      ; A = logical row
                STA     _conTmp0
                ASL
                ASL
                ASL
                ASL                         ; logical_row * 16
                STA     _Con_rrCbIdx
                LDA     _conTmp0
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                         ; logical_row * 64
                CLC
                ADC     _Con_rrCbIdx        ; = logical_row * 80
                STA     _Con_rrCbIdx

                ; SHR start offset for this vpRow = vpRow * 1280
                LDA     _Con_rrRow
                ASL                         ; *2 (word index)
                TAX
                LDA     _Con_RowOffsets,X
                STA     _Con_rrScreen

                LDA     #0
                STA     _Con_rrCol
                ; Phase 1 attr-run cache: seed the prev-cell key (_conTmp0/1/2 =
                ; attr/fg/bg) with an impossible fg ($FF; FGBUF only ever holds a
                ; 0..15 palette index) so the first cell of the row always misses.
                SEP     #$20
                LDA     #$FF
                STA     _conTmp1                ; prevFg sentinel
                REP     #$20

@rr_col         LDX     _Con_rrCbIdx
                PHX                         ; save CharBuf offset (decode clobbers X)
                SEP     #$20
                ; --- Attr-run cache: load this cell's (attr,fg,bg) at the three
                ;     reloc-patched sites; if all match the previous cell's key
                ;     (_conTmp0/1/2) reuse its variant (_conScratch5) + _conFontPtr
                ;     and skip the whole variant decode.  The decode is a PURE
                ;     function of exactly these three bytes, so a full-key match is
                ;     exact — no false hits.  Long same-attr runs (the common case)
                ;     pay only the 3 loads + 3 compares instead of the full decode.
_kcb016         LDAL    CON_ATTRBUF,X
                STA     _conScratch4        ; flags byte (B/I/U/G in bits 4..7)
_kcb017         LDAL    CON_FGBUF,X
                STA     _conScratch7        ; raw fg (temp; consumed on the miss path)
_kcb018         LDAL    CON_BGBUF,X
                STA     _conScratch7+1      ; raw bg (temp)
                LDA     _conScratch4
                CMP     _conTmp0            ; prevAttr?
                BNE     @rr_decode
                LDA     _conScratch7
                CMP     _conTmp1            ; prevFg?
                BNE     @rr_decode
                LDA     _conScratch7+1
                CMP     _conTmp2            ; prevBg?
                BNE     @rr_decode
                ; HIT: prev _conScratch5 (variant) + _conFontPtr are still valid.
                REP     #$20
                PLX                         ; restore CharBuf offset
                BRA     @rr_charGlyph
@rr_decode      MX      %10                 ; entered at M8/X16 from the cache compares
                ; MISS: record the new key, then compute the variant + font pointer.
                LDA     _conScratch4
                STA     _conTmp0            ; prevAttr
                LDA     _conScratch7
                STA     _conTmp1            ; prevFg
                LDA     _conScratch7+1
                STA     _conTmp2            ; prevBg
                ; Compose the 4-bit variant idx: the cells hold ANSI colour
                ; indexes, folded here to the row's four slots, fg in the low
                ; two bits and bg in the next two.  8-bit X for the table
                ; loads: a 16-bit TAX would carry B; the CharBuf offset is on
                ; the stack.
                SEP     #$10
                LDA     _conScratch7
                AND     #$0F
                TAX
                LDA     _Con_FgSlot,X
                STA     _conScratch5
                LDA     _conScratch7+1
                AND     #$0F
                TAX
                LDA     _Con_BgSlot,X
                REP     #$10
                ASL
                ASL
                ORA     _conScratch5
                STA     _conScratch5        ; raw variant (pre-inverse)
                LDA     _conScratch4
                AND     #$20                ; I bit
                BEQ     @rr_noInv
                ; See note in _Con_RenderCell: 16-bit X would pull garbage
                ; from _conScratch5's padding byte.
                SEP     #$10
                LDX     _conScratch5
                LDA     _Con_InvSwap,X
                STA     _conScratch5
                REP     #$10
@rr_noInv       REP     #$20
                LDA     _conScratch5
                AND     #$000F
                ASL                         ; *2 for word index
                TAX
                SEP     #$20
                LDA     _conScratch4
                AND     #$10                ; B bit
                BNE     @rr_bold
                REP     #$20
                LDA     _Con_RegularVariantBaseTbl,X
                BRA     @rr_haveBase
@rr_bold        REP     #$20
                LDA     _Con_BoldVariantBaseTbl,X
@rr_haveBase    STA     _conFontPtr
                SEP     #$20
_cfp112         LDAL    _kFontsBank         ; RELOC: dynamic fonts bank (was #$04)
                STA     _conFontPtr+2
                REP     #$20
                PLX                         ; restore CharBuf offset
@rr_charGlyph
                ; --- Char + G-bit glyph index. ---
                SEP     #$20
_kcb019         LDAL    CON_CHARBUF,X
                REP     #$20
                AND     #$007F              ; the font is seven-bit: a byte from
                                            ; $80 up draws as its low seven
                STA     _conScratch6        ; save char
                SEP     #$20
                LDA     _conScratch4
                AND     #$80                ; G bit
                BEQ     @rr_ascii
                REP     #$20
                LDA     _conScratch6
                CMP     #$60
                BCS     @rr_gfxOk1
                JMP     @rr_blank
@rr_gfxOk1      CMP     #$7F
                BCC     @rr_gfxOk2
                JMP     @rr_blank
@rr_gfxOk2      SEC
                SBC     #$60
                CLC
                ADC     #95
                BRA     @rr_haveIdx
@rr_ascii       REP     #$20
                LDA     _conScratch6
                SEC
                SBC     #32
                BCC     @rr_blank
                CMP     #95
                BCS     @rr_blank
@rr_haveIdx     ASL
                ASL
                ASL
                ASL                         ; *16 bytes per char
                TAY
                BEQ     @rr_blank           ; glyph 0 (space) -> uniform bg-fill fast path
                LDX     _Con_rrScreen
                LDA     [_conFontPtr],Y
                STAL    $012000,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $0120A0,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $012140,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $0121E0,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $012280,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $012320,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $0123C0,X
                INY
                INY
                LDA     [_conFontPtr],Y     ; scanline-7 glyph word
                ; Conditional underline: if U bit set, OR fill word for variant.
                PHA                         ; save glyph word
                SEP     #$20
                LDA     _conScratch4
                AND     #$40                ; U bit
                BEQ     @rr_ulDone
                REP     #$20
                LDA     _conScratch5        ; post-inverse variant idx
                AND     #$000F
                ASL                         ; *2 word index
                TAY                         ; Y = fill-table offset (X reserved for SHR)
                PLA                         ; recover glyph word
                ORA     _Con_UnderlineFill,Y
                BRA     @rr_ulStore
@rr_ulDone      REP     #$20
                PLA                         ; glyph word unchanged
@rr_ulStore     LDX     _Con_rrScreen
                STAL    $012460,X
@rr_next        INC     _Con_rrCbIdx
                LDA     _Con_rrScreen
                INC
                INC
                STA     _Con_rrScreen
                INC     _Con_rrCol
                LDA     _Con_rrCol
                CMP     _Con_RowBytes
                BCS     @rr_done
                JMP     @rr_col
@rr_done        RTS

@rr_blank       ; glyph 0 (space/blank): a space has no fg pixels, so all 8
                ; scanlines are the identical bg-fill word for this variant (verified
                ; uniform).  Load word 0 ONCE and replicate — skipping 7 font loads
                ; and all the INY stepping the normal blit needs.
                LDX     _Con_rrScreen
                LDA     [_conFontPtr]       ; word 0 = bg fill (Y=0)
                STAL    $012000,X
                STAL    $0120A0,X
                STAL    $012140,X
                STAL    $0121E0,X
                STAL    $012280,X
                STAL    $012320,X
                STAL    $0123C0,X
                ; scanline 7 = same bg word; OR the underline fill if the U bit is set.
                PHA                         ; save bg word
                SEP     #$20
                LDA     _conScratch4
                AND     #$40                ; U bit
                BEQ     @rr_blankUlDone
                REP     #$20
                LDA     _conScratch5
                AND     #$000F
                ASL
                TAY
                PLA
                ORA     _Con_UnderlineFill,Y
                BRA     @rr_blankStore
@rr_blankUlDone REP     #$20
                PLA
@rr_blankStore  STAL    $012460,X
                BRA     @rr_next

;------------------------------------------------------------------------------
; _Con_RenderCell - A = vpRow (0..24), X = col (0..79). Paint ONE char cell
; from CharBuf[logical_row * 80 + col]. Used by Con_PutChar for fast typing
; (~150 cycles vs ~48 000 for a full row render).
;------------------------------------------------------------------------------
_Con_RenderCell
                PHA                         ; save vpRow BEFORE the guard clobbers A
                LDA    |CON_VT_STATE+VT_RENDER_STATE
                AND     #$00FF
                CMP     #$0002
                BCC     @rc_go              ; state < 2: render
                BNE     @rc_skip            ; 3: a task owns the screen
                PLA                         ; 2: the flush draws it
                JMP     _Con_MarkDirty
@rc_skip        PLA                         ; rebalance stack, drop vpRow
                RTS
@rc_go          BIT    |_conBackendOn       ; a module's renderer? (console_backend.s)
                BPL     @rc_shr
                PLA                         ; vpRow, pushed at entry
                PHX                         ; col
                PHA                         ; vpRow
                JSR     _Con_LogicalRowFromVp
                TAY                         ; Y = ring row
                PLA                         ; A = vpRow
                PLX                         ; X = col
_Con_HkRenderCell JSL   $000000             ; operand written by Con_SetBackend
                RTS
@rc_shr         PHX                         ; save col
@rc_640mode     PLX
                PLA
                STA     _conTmp2            ; vpRow  (NB: NOT _conTmp4 — that
                STX     _conTmp5            ; col     overlaps _conFontPtr+2)
                ; logical_row = (topRow + vpRow) mod bufRows
                CLC
                ADC    |CON_VT_STATE+VT_TOP_ROW
                CMP    |CON_VT_STATE+VT_BUF_ROWS
                BCC     @rc_noWrap
                SBC    |CON_VT_STATE+VT_BUF_ROWS
@rc_noWrap      STA     _conTmp6            ; logical row
                ; cbOffset = logical_row * 80 + col
                ASL
                ASL
                ASL
                ASL                         ; *16
                STA     _conTmp0
                LDA     _conTmp6
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                         ; *64
                CLC
                ADC     _conTmp0            ; row*80
                CLC
                ADC     _conTmp5            ; + col
                TAX                         ; X = CharBuf byte offset

                ; --- Per-cell variant decode: B/I/U/G logic. ---
                PHX                         ; save CharBuf offset
                SEP     #$20
_kcb020         LDAL    CON_ATTRBUF,X
                STA     _conScratch4        ; flags byte (B/I/U/G in bits 4..7)
_kcb021         LDAL    CON_FGBUF,X
                PHA                         ; the fg's ANSI index
_kcb022         LDAL    CON_BGBUF,X
                ; Fold both ANSI indexes to the row's slots, as the row render
                ; does, under 8-bit X (the CharBuf offset is on the stack and
                ; _conScratch5+1 is another routine's cell).
                SEP     #$10
                AND     #$0F
                TAX
                LDA     _Con_BgSlot,X
                ASL
                ASL
                STA     _conScratch5        ; bg slot << 2
                PLA
                AND     #$0F
                TAX
                LDA     _Con_FgSlot,X
                REP     #$10
                ORA     _conScratch5
                STA     _conScratch5        ; raw variant
                LDA     _conScratch4
                AND     #$20                ; I bit
                BEQ     @rc_noInv
                ; _conScratch5 is a byte, but X is 16-bit here. A 16-bit
                ; LDX would pull garbage from the padding byte ($DB — alias
                ; of _fsTmp1's high byte), landing us way outside the
                ; 16-entry _Con_InvSwap table. Drop to 8-bit X for the
                ; indexed load, then restore.
                SEP     #$10
                LDX     _conScratch5
                LDA     _Con_InvSwap,X
                STA     _conScratch5
                REP     #$10
@rc_noInv       REP     #$20
                LDA     _conScratch5
                AND     #$000F
                ASL
                TAX
                SEP     #$20
                LDA     _conScratch4
                AND     #$10                ; B bit
                BNE     @rc_bold
                REP     #$20
                LDA     _Con_RegularVariantBaseTbl,X
                BRA     @rc_haveBase
@rc_bold        REP     #$20
                LDA     _Con_BoldVariantBaseTbl,X
@rc_haveBase    STA     _conFontPtr
                SEP     #$20
_cfp113         LDAL    _kFontsBank         ; RELOC: dynamic fonts bank (was #$04)
                STA     _conFontPtr+2
                REP     #$20
                PLX                         ; restore CharBuf offset
                ; --- Char + G-bit glyph index. ---
                SEP     #$20
_kcb023         LDAL    CON_CHARBUF,X
                REP     #$20
                AND     #$007F              ; seven-bit font, as the row render
                STA     _conScratch6
                SEP     #$20
                LDA     _conScratch4
                AND     #$80                ; G bit
                BEQ     @rc_ascii
                REP     #$20
                LDA     _conScratch6
                CMP     #$60
                BCC     @rc_blank
                CMP     #$7F
                BCS     @rc_blank
                SEC
                SBC     #$60
                CLC
                ADC     #95
                BRA     @rc_haveIdx
@rc_ascii       REP     #$20
                LDA     _conScratch6
                SEC
                SBC     #32
                BCC     @rc_blank
                CMP     #95
                BCS     @rc_blank
@rc_haveIdx     ASL
                ASL
                ASL
                ASL
                TAY                         ; Y = glyph byte offset
                BRA     @rc_render
@rc_blank       LDY     #0                  ; space glyph
@rc_render
                ; Screen X = RowBaseOffsets[vpRow] + col * 2
                LDA     _conTmp2            ; vpRow
                ASL
                TAX
                LDA     _Con_RowOffsets,X
                CLC
                ADC     _conTmp5
                ADC     _conTmp5
                TAX                         ; X = SHR byte offset
                LDA     [_conFontPtr],Y
                STAL    $012000,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $0120A0,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $012140,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $0121E0,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $012280,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $012320,X
                INY
                INY
                LDA     [_conFontPtr],Y
                STAL    $0123C0,X
                INY
                INY
                LDA     [_conFontPtr],Y     ; glyph scanline-7 word
                ; Optional underline OR.
                PHA
                SEP     #$20
                LDA     _conScratch4
                AND     #$40                ; U bit
                BEQ     @rc_ulDone
                REP     #$20
                LDA     _conScratch5
                AND     #$000F
                ASL
                TAY                         ; word index for _Con_UnderlineFill
                PLA
                ORA     _Con_UnderlineFill,Y
                BRA     @rc_ulStore
@rc_ulDone      REP     #$20
                PLA
@rc_ulStore     STAL    $012460,X
                RTS

;------------------------------------------------------------------------------
; Con_RenderAll - paint all 25 visible rows from CharBuf.
;------------------------------------------------------------------------------
Con_RenderAll   MX      %00                     ; caller convention: enter at M=0
                LDA     #0
@ra_L           PHA
                JSR     Con_RenderRow
                PLA
                INC
                CMP     _Con_VisRows
                BCC     @ra_L
                RTS

;------------------------------------------------------------------------------
; Row base offsets into SHR (bank $01 shadow). Each row = 8 scanlines * 160
; bytes = 1280 bytes.
;------------------------------------------------------------------------------
_Con_RowOffsets
                DA      0, 1280, 2560, 3840, 5120, 6400, 7680, 8960
                DA      10240, 11520, 12800, 14080, 15360, 16640, 17920, 19200
                DA      20480, 21760, 23040, 24320, 25600, 26880, 28160, 29440
                DA      30720

;------------------------------------------------------------------------------
; _Con_InvSwap - 16-entry table, entry i = nibble-swap of i
; (bits 0..1 swapped with bits 2..3). Used by the inverse-video (I) attr
; bit to remap variant index (fg,bg) -> (bg,fg) in one indexed load.
;------------------------------------------------------------------------------
_Con_InvSwap
                DFB     $00     ; 0000 -> 0000
                DFB     $04     ; 0001 -> 0100
                DFB     $08     ; 0010 -> 1000
                DFB     $0C     ; 0011 -> 1100
                DFB     $01     ; 0100 -> 0001
                DFB     $05     ; 0101 -> 0101
                DFB     $09     ; 0110 -> 1001
                DFB     $0D     ; 0111 -> 1101
                DFB     $02     ; 1000 -> 0010
                DFB     $06     ; 1001 -> 0110
                DFB     $0A     ; 1010 -> 1010
                DFB     $0E     ; 1011 -> 1110
                DFB     $03     ; 1100 -> 0011
                DFB     $07     ; 1101 -> 0111
                DFB     $0B     ; 1110 -> 1011
                DFB     $0F     ; 1111 -> 1111

;==============================================================================
; END console_render.s
;==============================================================================

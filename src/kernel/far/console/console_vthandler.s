                MX      %00                 ; reset Merlin mode tracking (M=0, X=0)
;==============================================================================
; console_vthandler.s - VT sequence handlers (Plan 2).
;
; CPU mode convention:
;   - Handlers are called via JSR from _Vt_DispatchCsi / _Vt_DispatchEsc which
;     bracket with REP #$20 / SEP #$20. So handlers enter and exit in M=0
;     (16-bit A).
;   - X is 16-bit throughout (MX %00 at file level).
;   - When a handler needs 8-bit operations on byte-sized DP state, it does
;     SEP #$20 + REP #$20 inline. This keeps Merlin's static view synced.
;   - Helpers (_Vt_ReadParam*, _Vt_FillAttr*) are M=0 entry/exit as well.
;==============================================================================

;------------------------------------------------------------------------------
; _Vt_DispatchCsiByFinal - A (16-bit) = final byte. Dispatch via compare chain
; and JMP to the chosen handler. Each handler RTSes to the caller of
; _Vt_DispatchCsiByFinal (which is _Vt_DispatchCsi in console_vt.s).
;------------------------------------------------------------------------------
_Vt_DispatchCsiByFinal
                CMP     #'A'
                BNE     @vdc_1
                JMP     _Vt_Handle_CUU
@vdc_1          CMP     #'B'
                BNE     @vdc_2
                JMP     _Vt_Handle_CUD
@vdc_2          CMP     #'C'
                BNE     @vdc_3
                JMP     _Vt_Handle_CUF
@vdc_3          CMP     #'D'
                BNE     @vdc_4
                JMP     _Vt_Handle_CUB
@vdc_4          CMP     #'H'
                BNE     @vdc_5
                JMP     _Vt_Handle_CUP
@vdc_5          CMP     #'J'
                BNE     @vdc_6
                JMP     _Vt_Handle_ED
@vdc_6          CMP     #'K'
                BNE     @vdc_G
                JMP     _Vt_Handle_EL
@vdc_G          CMP     #'G'
                BNE     @vdc_7
                JMP     _Vt_Handle_CHA
@vdc_7          CMP     #'f'
                BNE     @vdc_8
                JMP     _Vt_Handle_CUP
@vdc_8          CMP     #'m'
                BNE     @vdc_9
                JMP     _Vt_Handle_SGR
@vdc_9          CMP     #'s'
                BNE     @vdc_10
                JMP     _Vt_Handle_DECSC
@vdc_10         CMP     #'u'
                BNE     @vdc_11
                JMP     _Vt_Handle_DECRC
@vdc_11         CMP     #'r'
                BNE     @vdc_12
                JMP     _Vt_Handle_DECSTBM
@vdc_12         CMP     #'S'
                BNE     @vdc_13
                JMP     _Vt_Handle_SU
@vdc_13         CMP     #'T'
                BNE     @vdc_14
                JMP     _Vt_Handle_SD
@vdc_14         CMP     #'h'
                BNE     @vdc_15
                JMP     _Vt_Handle_SetMode
@vdc_15         CMP     #'l'
                BNE     @vdc_16
                JMP     _Vt_Handle_ResetMode
@vdc_16         CMP     #'g'
                BNE     @vdc_17
                JMP     _Vt_Handle_TBC
@vdc_17         CMP     #'n'
                BNE     @vdc_18
                JMP     _Vt_Handle_DSR
@vdc_18         CMP     #'c'
                BNE     @vdc_19
                JMP     _Vt_Handle_DA
@vdc_19         CMP     #$5D                    ; ']'
                BNE     @vdc_unknown
                JMP     _Vt_Handle_RSB
@vdc_unknown    RTS

;------------------------------------------------------------------------------
; _Vt_ReadParam - A = idx. Returns A (16-bit) = param value or 0 if missing.
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_ReadParam
                AND     #$00FF
                SEP     #$20                ; 8-bit for byte compare
                CMP     |CON_VT_STATE+VT_NPARAMS
                REP     #$20                ; back to M=0 (C preserved)
                BCC     @rp_ok
                LDA     #0
                RTS
@rp_ok
                AND     #$00FF
                ASL                         ; idx * 2
                AND     #$00FF              ; safety
                TAX
                LDA     |CON_VT_STATE+VT_PARAMS,X
                RTS

;------------------------------------------------------------------------------
; _Vt_ReadParamDefault - A = idx, X = default. Returns A (16-bit) = param
; value or default if param is missing or zero.
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_ReadParamDefault
                PHX                         ; save default (16-bit)
                JSR     _Vt_ReadParam       ; A = 16-bit param (0 if missing)
                PLY                         ; Y = default (16-bit from stack)
                CMP     #0
                BNE     @rpd_done
                TYA                         ; use default
@rpd_done       RTS

;------------------------------------------------------------------------------
; _Vt_Handle_CUP - CSI r;c H → cursor at (row-1, col-1), clamped.
;------------------------------------------------------------------------------
_Vt_Handle_CUP
                LDA     #0
                LDX     #1
                JSR     _Vt_ReadParamDefault
                SEC
                SBC     #1                  ; 0-based
                CMP     _Con_VisRows
                BCC     @cup_rowOk
                LDA     _Con_VisRowsM1
@cup_rowOk      STA    |CON_VT_STATE+VT_CUR_ROW
                LDA     #1
                LDX     #1
                JSR     _Vt_ReadParamDefault
                SEC
                SBC     #1
                CMP     _Con_RowBytes
                BCC     @cup_colOk
                LDA     _Con_RowBytes
                DEC
@cup_colOk      STA    |CON_VT_STATE+VT_CUR_COL
                JSR     _Con_ClearPendingWrap
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_CUU - CSI n A → cursor up n, clamp to 0.
;------------------------------------------------------------------------------
_Vt_Handle_CUU
                LDA     #0
                LDX     #1
                JSR     _Vt_ReadParamDefault
                STA     _conScratch0
                LDA    |CON_VT_STATE+VT_CUR_ROW
                CMP     _conScratch0
                BCS     @cuu_inRange
                LDA     #0
                BRA     @cuu_set
@cuu_inRange    SEC
                SBC     _conScratch0
@cuu_set        STA    |CON_VT_STATE+VT_CUR_ROW
                JSR     _Con_ClearPendingWrap
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_CUD - CSI n B → cursor down n, clamp at bottom.
;------------------------------------------------------------------------------
_Vt_Handle_CUD
                LDA     #0
                LDX     #1
                JSR     _Vt_ReadParamDefault
                STA     _conScratch0
                LDA    |CON_VT_STATE+VT_CUR_ROW
                CLC
                ADC     _conScratch0
                CMP     _Con_VisRows
                BCC     @cud_set
                LDA     _Con_VisRowsM1
@cud_set        STA    |CON_VT_STATE+VT_CUR_ROW
                JSR     _Con_ClearPendingWrap
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_CUF - CSI n C → cursor forward n, clamp at rightmost col.
;------------------------------------------------------------------------------
_Vt_Handle_CUF
                LDA     #0
                LDX     #1
                JSR     _Vt_ReadParamDefault
                STA     _conScratch0
                LDA    |CON_VT_STATE+VT_CUR_COL
                CLC
                ADC     _conScratch0
                CMP     _Con_RowBytes
                BCC     @cuf_set
                LDA     _Con_RowBytes
                DEC
@cuf_set        STA    |CON_VT_STATE+VT_CUR_COL
                JSR     _Con_ClearPendingWrap
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_CUB - CSI n D → cursor back n, clamp at col 0.
;------------------------------------------------------------------------------
_Vt_Handle_CUB
                LDA     #0
                LDX     #1
                JSR     _Vt_ReadParamDefault
                STA     _conScratch0
                LDA    |CON_VT_STATE+VT_CUR_COL
                CMP     _conScratch0
                BCS     @cub_inRange
                LDA     #0
                BRA     @cub_set
@cub_inRange    SEC
                SBC     _conScratch0
@cub_set        STA    |CON_VT_STATE+VT_CUR_COL
                JSR     _Con_ClearPendingWrap
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_ED - CSI n J. Erase display.
;------------------------------------------------------------------------------
_Vt_Handle_ED
                LDA     #0
                LDX     #0
                JSR     _Vt_ReadParamDefault
                CMP     #2
                BEQ     @ed_all
                CMP     #1
                BEQ     @ed_toCursor
                JMP     _Vt_Erase_CursorToEnd
@ed_all
                JSR     Con_Clear               ; clear SHR pixels
                JSR     _Con_FillCharBuf        ; clear CharBuf (else RenderAll paints old text back)
                JSR     _Vt_FillAttrBuf_Current
                ; A BLANK CELL DRAWS ONLY ITS BACKGROUND, which Con_Clear has
                ; just painted, unless inverse or underline marks it -- so the
                ; repaint of every blank cell is skipped then.  A module's
                ; renderer still gets it: Con_Clear only told it to clear.
                BIT    |_conBackendOn
                BMI     @ed_render
                SEP     #$20
                LDA    |CON_VT_STATE+VT_ATTR
                AND     #$60                    ; I | U
                REP     #$20
                BNE     @ed_render
                RTS
@ed_render      JMP     Con_RenderAll
@ed_toCursor
                JMP     _Vt_Erase_StartToCursor

;------------------------------------------------------------------------------
; _Vt_Handle_EL - CSI n K. Erase line.
;------------------------------------------------------------------------------
_Vt_Handle_EL
                LDA     #0
                LDX     #0
                JSR     _Vt_ReadParamDefault
                CMP     #2
                BEQ     @el_all
                CMP     #1
                BEQ     @el_toCursor
                JMP     _Vt_Erase_LineCursorToEnd
@el_all
                JMP     _Vt_Erase_EntireLine
@el_toCursor
                JMP     _Vt_Erase_LineStartToCursor

;------------------------------------------------------------------------------
; _Vt_Handle_CHA - CSI n G. Cursor to column n (1-based).
; Param 0 or missing = column 1. Clamped to _Con_RowBytes-1.
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_CHA
                LDA     #0
                LDX     #1
                JSR     _Vt_ReadParamDefault    ; A = column (1-based, or 1 if missing/zero)
                AND     #$00FF
                BNE     @cha_nonZero
                LDA     #1                      ; 0 → treat as 1
@cha_nonZero    SEC
                SBC     #1                      ; 0-based
                CMP     _Con_RowBytes
                BCC     @cha_ok
                LDA     _Con_RowBytes           ; clamp to RowBytes-1
                DEC
@cha_ok         SEP     #$20
                STA    |CON_VT_STATE+VT_CUR_COL
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_Erase_LineCursorToEnd - spaces + _conAttr from cursor col to RowBytes-1.
;------------------------------------------------------------------------------
_Vt_Erase_LineCursorToEnd
                LDA    |CON_VT_STATE+VT_CUR_ROW
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_RingOffset         ; A = row*80
                CLC
                ADC    |CON_VT_STATE+VT_CUR_COL
                STA     _conScratch0            ; cell offset
                LDA    |CON_VT_STATE+VT_CUR_COL
                STA     _conScratch1            ; running col
@elce_L
                SEP     #$20
                LDA     #$20
                LDX     _conScratch0
_kcb032         STAL    CON_CHARBUF,X
                LDA    |CON_VT_STATE+VT_ATTR
_kcb033         STAL    CON_ATTRBUF,X
                LDA    |CON_VT_STATE+VT_FG
_kcb034         STAL    CON_FGBUF,X
                LDA    |CON_VT_STATE+VT_BG
_kcb035         STAL    CON_BGBUF,X
                REP     #$20
                INC     _conScratch0
                INC     _conScratch1
                LDA     _conScratch1
                CMP     _Con_RowBytes
                BCC     @elce_L
                LDA    |CON_VT_STATE+VT_CUR_ROW
                JMP     Con_RenderRow

;------------------------------------------------------------------------------
; _Vt_Erase_LineStartToCursor - spaces from col 0 to cursor inclusive.
;------------------------------------------------------------------------------
_Vt_Erase_LineStartToCursor
                LDA    |CON_VT_STATE+VT_CUR_ROW
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_RingOffset         ; A = row*80
                STA     _conScratch0            ; cell offset
                LDA     #0
                STA     _conScratch1            ; running col
@elsc_L
                SEP     #$20
                LDA     #$20
                LDX     _conScratch0
_kcb036         STAL    CON_CHARBUF,X
                LDA    |CON_VT_STATE+VT_ATTR
_kcb037         STAL    CON_ATTRBUF,X
                LDA    |CON_VT_STATE+VT_FG
_kcb038         STAL    CON_FGBUF,X
                LDA    |CON_VT_STATE+VT_BG
_kcb039         STAL    CON_BGBUF,X
                REP     #$20
                INC     _conScratch0
                INC     _conScratch1
                LDA     _conScratch1
                CMP    |CON_VT_STATE+VT_CUR_COL
                BCC     @elsc_L
                BEQ     @elsc_L
                LDA    |CON_VT_STATE+VT_CUR_ROW
                JMP     Con_RenderRow

;------------------------------------------------------------------------------
; _Vt_Erase_EntireLine - entire current row → spaces + _conAttr.
;------------------------------------------------------------------------------
_Vt_Erase_EntireLine
                LDA    |CON_VT_STATE+VT_CUR_ROW
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_ClearRingRow
                LDA    |CON_VT_STATE+VT_CUR_ROW
                JSR     _Vt_FillAttrRow_At
                LDA    |CON_VT_STATE+VT_CUR_ROW
                JMP     Con_RenderRow

;------------------------------------------------------------------------------
; _Vt_Erase_CursorToEnd - cursor to end of screen.
;------------------------------------------------------------------------------
_Vt_Erase_CursorToEnd
                JSR     _Vt_Erase_LineCursorToEnd_noRender
                LDA    |CON_VT_STATE+VT_CUR_ROW
                INC
                STA     _conScratch2        ; first row below cursor
@cte_L
                LDA     _conScratch2
                CMP     _Con_VisRows
                BCS     @cte_done
                LDA     _conScratch2
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_ClearRingRow
                LDA     _conScratch2
                JSR     _Vt_FillAttrRow_At
                INC     _conScratch2
                BRA     @cte_L
@cte_done
                JMP     Con_RenderAll

;------------------------------------------------------------------------------
; _Vt_Erase_LineCursorToEnd_noRender - as above but skip final Con_RenderRow.
; Used by _Vt_Erase_CursorToEnd which does its own full-screen render.
;------------------------------------------------------------------------------
_Vt_Erase_LineCursorToEnd_noRender
                LDA    |CON_VT_STATE+VT_CUR_ROW
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_RingOffset
                CLC
                ADC    |CON_VT_STATE+VT_CUR_COL
                STA     _conScratch0
                LDA    |CON_VT_STATE+VT_CUR_COL
                STA     _conScratch1
@elcenr_L
                SEP     #$20
                LDA     #$20
                LDX     _conScratch0
_kcb040         STAL    CON_CHARBUF,X
                LDA    |CON_VT_STATE+VT_ATTR
_kcb041         STAL    CON_ATTRBUF,X
                LDA    |CON_VT_STATE+VT_FG
_kcb042         STAL    CON_FGBUF,X
                LDA    |CON_VT_STATE+VT_BG
_kcb043         STAL    CON_BGBUF,X
                REP     #$20
                INC     _conScratch0
                INC     _conScratch1
                LDA     _conScratch1
                CMP     _Con_RowBytes
                BCC     @elcenr_L
                RTS

;------------------------------------------------------------------------------
; _Vt_Erase_StartToCursor - (0,0) through cursor inclusive.
;------------------------------------------------------------------------------
_Vt_Erase_StartToCursor
                LDA     #0
                STA     _conScratch2
@stc_L
                LDA     _conScratch2
                CMP    |CON_VT_STATE+VT_CUR_ROW
                BEQ     @stc_partial
                BCS     @stc_done
                LDA     _conScratch2
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_ClearRingRow
                LDA     _conScratch2
                JSR     _Vt_FillAttrRow_At
                INC     _conScratch2
                BRA     @stc_L
@stc_partial
                JSR     _Vt_Erase_LineStartToCursor_noRender
@stc_done
                JMP     Con_RenderAll

_Vt_Erase_LineStartToCursor_noRender
                LDA    |CON_VT_STATE+VT_CUR_ROW
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_RingOffset
                STA     _conScratch0
                LDA     #0
                STA     _conScratch1
@elscnr_L
                SEP     #$20
                LDA     #$20
                LDX     _conScratch0
_kcb044         STAL    CON_CHARBUF,X
                LDA    |CON_VT_STATE+VT_ATTR
_kcb045         STAL    CON_ATTRBUF,X
                LDA    |CON_VT_STATE+VT_FG
_kcb046         STAL    CON_FGBUF,X
                LDA    |CON_VT_STATE+VT_BG
_kcb047         STAL    CON_BGBUF,X
                REP     #$20
                INC     _conScratch0
                INC     _conScratch1
                LDA     _conScratch1
                CMP    |CON_VT_STATE+VT_CUR_COL
                BCC     @elscnr_L
                BEQ     @elscnr_L
                RTS

;------------------------------------------------------------------------------
; _Vt_FillAttrBuf_Current - fill ATTRBUF / FGBUF / BGBUF with current
; _conAttr / _conFg / _conBg across all 8000 cells.  Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_FillAttrBuf_Current
                SEP     #$20
                LDA    |CON_VT_STATE+VT_ATTR
_kcb048         STAL    CON_ATTRBUF
                REP     #$30
                LDX     #$2000
                LDY     #$2001
                LDA     #7998
_kcm017         MVN     $03,$03
                SEP     #$20
                _DBRK                       ; MVN left DBR on $03; the read is
                                            ;   DBR-relative now that VT_FG is
                                            ;   a far-bank static, not a DP cell
                LDA    |CON_VT_STATE+VT_FG
_kcb049         STAL    CON_FGBUF
                REP     #$30
                LDX     #$4000
                LDY     #$4001
                LDA     #7998
_kcm018         MVN     $03,$03
                SEP     #$20
                _DBRK                       ; same
                LDA    |CON_VT_STATE+VT_BG
_kcb050         STAL    CON_BGBUF
                REP     #$30
                LDX     #$6000
                LDY     #$6001
                LDA     #7998
_kcm019         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_FillAttrRow_At - A = vpRow.  Fill that row's ATTRBUF / FGBUF / BGBUF
; cells with current _conAttr / _conFg / _conBg.  Entry/exit: M=0.
;
; _DBRK after EVERY MVN, not just the last.  MVN leaves DBR = the destination
; bank (the console bank); the next block then reads its byte count with
; `LDA _Con_RowBytesM2`, which is ABSOLUTE and therefore DBR-relative.  With DBR
; still pointing at the console bank that read returns whatever CHARBUF holds at
; the same offset -- $2020 (two spaces) = 8224 once the buffer has been used --
; and the MVN smears the fill byte across FGBUF/BGBUF/the alt-screen snapshots
; instead of the 79 bytes it meant to fill.  That was the whole-screen inverse
; video after the first scroll.
;------------------------------------------------------------------------------
_Vt_FillAttrRow_At
                AND     #$00FF
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_RingOffset     ; A = row*80
                STA     _conScratch0        ; save cell offset for reuse
                TAX
                ; ATTRBUF row -> _conAttr
                SEP     #$20
                LDA    |CON_VT_STATE+VT_ATTR
_kcb051         STAL    CON_ATTRBUF,X
                REP     #$30
                TXA
                CLC
                ADC     #$2000
                TAX
                INC
                TAY
                LDA     _Con_RowBytesM2
_kcm020         MVN     $03,$03
                _DBRK                       ; MVN left DBR = console bank
                ; FGBUF row -> _conFg
                LDX     _conScratch0
                SEP     #$20
                LDA    |CON_VT_STATE+VT_FG
_kcb052         STAL    CON_FGBUF,X
                REP     #$30
                TXA
                CLC
                ADC     #$4000
                TAX
                INC
                TAY
                LDA     _Con_RowBytesM2
_kcm021         MVN     $03,$03
                _DBRK                       ; MVN left DBR = console bank
                ; BGBUF row -> _conBg
                LDX     _conScratch0
                SEP     #$20
                LDA    |CON_VT_STATE+VT_BG
_kcb053         STAL    CON_BGBUF,X
                REP     #$30
                TXA
                CLC
                ADC     #$6000
                TAX
                INC
                TAY
                LDA     _Con_RowBytesM2
_kcm022         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_DECSC - save cursor + attr + palette.
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_DECSC
                SEP     #$20
                LDA    |CON_VT_STATE+VT_CUR_ROW
                STA    |CON_VT_STATE+VT_SAVED_ROW
                LDA    |CON_VT_STATE+VT_CUR_COL
                STA    |CON_VT_STATE+VT_SAVED_COL
                LDA    |CON_VT_STATE+VT_ATTR
                STA    |CON_VT_STATE+VT_SAVED_ATTR
                LDA    |CON_VT_STATE+VT_ROW_PALETTE
                STA    |CON_VT_STATE+VT_SAVED_PAL
                LDA    |CON_VT_STATE+VT_G0_CHARSET
                STA    |CON_VT_STATE+VT_SAVED_G0
                LDA    |CON_VT_STATE+VT_G1_CHARSET
                STA    |CON_VT_STATE+VT_SAVED_G1
                LDA    |CON_VT_STATE+VT_GL
                STA    |CON_VT_STATE+VT_SAVED_GL
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_DECRC - restore saved cursor + attr + palette.
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_DECRC
                SEP     #$20
                LDA    |CON_VT_STATE+VT_SAVED_ROW
                STA    |CON_VT_STATE+VT_CUR_ROW
                LDA    |CON_VT_STATE+VT_SAVED_COL
                STA    |CON_VT_STATE+VT_CUR_COL
                LDA    |CON_VT_STATE+VT_SAVED_ATTR
                STA    |CON_VT_STATE+VT_ATTR
                LDA    |CON_VT_STATE+VT_SAVED_PAL
                STA    |CON_VT_STATE+VT_ROW_PALETTE
                LDA    |CON_VT_STATE+VT_SAVED_G0
                STA    |CON_VT_STATE+VT_G0_CHARSET
                LDA    |CON_VT_STATE+VT_SAVED_G1
                STA    |CON_VT_STATE+VT_G1_CHARSET
                LDA    |CON_VT_STATE+VT_SAVED_GL
                STA    |CON_VT_STATE+VT_GL
                ; Explicit cursor positioning clears deferred-wrap state.
                LDA     #0
                STA    |CON_VT_STATE+VT_PENDING_WRAP
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_SGR - walk params, update SgrState, call _Vt_ApplySgr.
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_SGR
                SEP     #$20
                LDA    |CON_VT_STATE+VT_NPARAMS
                BNE     @sgr_haveParams
                ; Missing params = SGR 0 (reset).
                LDA     #$FF
                STA    |CON_VT_STATE+VT_SGR_FG
                STA    |CON_VT_STATE+VT_SGR_BG
                LDA     #0
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                REP     #$20
                JMP     _Vt_ApplySgr
@sgr_haveParams MX      %10                     ; runtime reaches here in M=1 via BNE
                LDA     #0
                STA     _conScratch0            ; param idx
@sgr_L          MX      %10
                REP     #$20
                LDA     _conScratch0
                AND     #$00FF
                JSR     _Vt_ReadParam           ; M=0 entry/exit, returns A = value
                AND     #$00FF
                SEP     #$20
                JSR     _Vt_ApplyOneSgr
                INC     _conScratch0
                LDA     _conScratch0
                CMP     |CON_VT_STATE+VT_NPARAMS
                BCC     @sgr_L
                REP     #$20
                JMP     _Vt_ApplySgr

;------------------------------------------------------------------------------
; _Vt_SgrBlink / _Vt_SgrSteady - SGR 5 / 25.  Blink is iCE colour: the flag
; is bit 3 and _Vt_ApplySgr ORs it into the background as the bright bit.
; _Vt_SgrExtFg / _Vt_SgrExtBg - SGR 38 / 48, into _Vt_SgrExt.
; Above _Vt_ApplyOneSgr because its compare chain branches here, and the
; handlers below the chain are out of a branch's reach.  M=1.
;------------------------------------------------------------------------------
_Vt_SgrBlink    MX      %10
                LDA     |CON_VT_STATE+VT_SGR_FLAGS
                ORA     #$08
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                RTS
_Vt_SgrSteady   MX      %10
                LDA     |CON_VT_STATE+VT_SGR_FLAGS
                AND     #$F7
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                RTS
_Vt_SgrExtFg    MX      %10                     ; SGR 38: _Vt_SgrExt, C=0
                CLC
                JMP     _Vt_SgrExt
_Vt_SgrExtBg    MX      %10                     ; SGR 48: _Vt_SgrExt, C=1
                SEC
                JMP     _Vt_SgrExt

;------------------------------------------------------------------------------
; _Vt_ApplyOneSgr - A (8-bit) = one SGR code. Updates VT_SGR_* fields.
; Entry/exit: M=1.
;------------------------------------------------------------------------------
_Vt_ApplyOneSgr MX      %10
                CMP     #0
                BEQ     @aos_reset
                CMP     #1
                BEQ     @aos_bold
                CMP     #4
                BEQ     @aos_underline
                CMP     #5
                BEQ     _Vt_SgrBlink
                CMP     #7
                BEQ     @aos_reverse
                CMP     #22
                BEQ     @aos_notBold
                CMP     #24
                BEQ     @aos_notUnderline
                CMP     #25
                BEQ     _Vt_SgrSteady
                CMP     #27
                BEQ     @aos_notReverse
                CMP     #30
                BCC     @aos_done
                CMP     #38
                BCC     @aos_fgStd
                BEQ     _Vt_SgrExtFg
                CMP     #39
                BEQ     @aos_fgDefault
                CMP     #40
                BCC     @aos_done
                CMP     #48
                BCC     @aos_bgStd
                BEQ     _Vt_SgrExtBg
                CMP     #49
                BEQ     @aos_bgDefault
                CMP     #90
                BCC     @aos_done
                CMP     #98
                BCC     @aos_fgBright
                CMP     #100
                BCC     @aos_done
                CMP     #108
                BCC     @aos_bgBright
@aos_done
                RTS
@aos_reset
                LDA     #$FF
                STA    |CON_VT_STATE+VT_SGR_FG
                STA    |CON_VT_STATE+VT_SGR_BG
                LDA     #0
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                RTS
@aos_bold
                LDA     |CON_VT_STATE+VT_SGR_FLAGS
                ORA     #$01
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                RTS
@aos_reverse
                LDA     |CON_VT_STATE+VT_SGR_FLAGS
                ORA     #$02
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                RTS
@aos_underline
                LDA     |CON_VT_STATE+VT_SGR_FLAGS
                ORA     #$04
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                RTS
@aos_notBold
                LDA     |CON_VT_STATE+VT_SGR_FLAGS
                AND     #$FE
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                RTS
@aos_notReverse
                LDA     |CON_VT_STATE+VT_SGR_FLAGS
                AND     #$FD
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                RTS
@aos_notUnderline
                LDA     |CON_VT_STATE+VT_SGR_FLAGS
                AND     #$FB
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                RTS
@aos_fgStd
                SEC
                SBC     #30
                STA    |CON_VT_STATE+VT_SGR_FG
                RTS
@aos_fgDefault
                LDA     #$FF
                STA    |CON_VT_STATE+VT_SGR_FG
                RTS
@aos_bgStd
                SEC
                SBC     #40
                STA    |CON_VT_STATE+VT_SGR_BG
                RTS
@aos_bgDefault
                LDA     #$FF
                STA    |CON_VT_STATE+VT_SGR_BG
                RTS
@aos_fgBright
                SEC
                SBC     #90
                CLC
                ADC     #8
                STA    |CON_VT_STATE+VT_SGR_FG
                RTS
@aos_bgBright
                SEC
                SBC     #100
                CLC
                ADC     #8
                STA    |CON_VT_STATE+VT_SGR_BG
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_RSB - CSI Ps ], the Linux console's private sequences
; (console_codes(4)).  Only Ps = 8 is taken: "Make the current color pair
; the default attributes."  Linux (vt.c, CSI_RSB_MAKE_CUR_COLOR_DEFAULT)
; copies the attribute as displayed, then resets every attribute to it
; (default_attr); here the pair is taken as the card displays it -- the two
; swapped under reverse, the foreground bright under bold, blink already in
; VT_BG -- into VT_DEF_COLOR, and the SGR state resets to it.  The pair is
; this console's: the VT state is per VC.  Other Ps are ignored.
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_RSB  MX      %00
                LDA     #0
                JSR     _Vt_ReadParam           ; A = Ps, 0 if missing
                CMP     #8
                BEQ     @rsb_8
                RTS
@rsb_8          SEP     #$20
                LDA    |CON_VT_STATE+VT_SGR_FLAGS
                AND     #$02                    ; reverse: the pair shows swapped
                BEQ     @rsb_plain
                LDA    |CON_VT_STATE+VT_FG
                ASL
                ASL
                ASL
                ASL
                ORA    |CON_VT_STATE+VT_BG
                BRA     @rsb_bold
@rsb_plain      LDA    |CON_VT_STATE+VT_BG
                ASL
                ASL
                ASL
                ASL
                ORA    |CON_VT_STATE+VT_FG
@rsb_bold       STA     _conScratch1            ; bg<<4 | fg as displayed
                LDA    |CON_VT_STATE+VT_SGR_FLAGS
                AND     #$01                    ; bold: the bright foreground
                BEQ     @rsb_set
                LDA     _conScratch1
                ORA     #$08
                STA     _conScratch1
@rsb_set        LDA     _conScratch1
                STA    |CON_VT_STATE+VT_DEF_COLOR
                LDA     #$FF
                STA    |CON_VT_STATE+VT_SGR_FG
                STA    |CON_VT_STATE+VT_SGR_BG
                LDA     #0
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                REP     #$20
                JMP     _Vt_ApplySgr

;------------------------------------------------------------------------------
; _Vt_SgrExt - SGR 38 (C=0) or 48 (C=1) and the colour that follows it, in
; the two forms console_codes(4) gives: ";5;x 256 color: values 0..15 are
; IBGR (black, red, green, ..., white), 16..231 a 6x6x6 color cube, 232..255
; a grayscale ramp" and ";2;r;g;b 24-bit color".  Read as Linux vt.c's
; vc_t416_color reads them: the selector is consumed whatever it is, and a
; form short of its numbers is consumed as far as it goes and changes
; nothing.  The colour is then "shoehorned into 16 basic colors": x below 16
; as it is; otherwise rgb_from_256 gives r,g,b, which rgb_foreground or
; rgb_background fold (_Vt_RgbFg, _Vt_RgbBg).  Linux sets the bold intensity
; for a bright foreground; here the index is the bright one, bold being an
; attribute of its own.  The colon-separated forms never arrive: the parser
; takes ':' as a bad parameter byte and ignores the whole sequence.
;
; In:  M=1, C = 0 foreground / 1 background, _conScratch0 = the index of the
;      38 or 48.
; Out: M=1, _conScratch0 = the index of the last parameter consumed, which
;      the SGR loop steps past.  Clobbers X, Y, _conScratch1-4, _conTmp0-2.
;------------------------------------------------------------------------------
_Vt_SgrExt      MX      %10
                PHP                             ; the carry, read back at 1,S
                REP     #$20
                MX      %00
                LDA    |CON_VT_STATE+VT_NPARAMS
                AND     #$00FF
                STA     _conTmp0                ; n
                LDA     _conScratch0
                AND     #$00FF
                INC                             ; i: the selector
                STA     _conScratch0
                CMP     _conTmp0
                BCS     @x_out                  ; none: the 38 alone
                JSR     _Vt_ReadParam           ; A = par[i]
                CMP     #5
                BEQ     @x_256
                CMP     #2
                BNE     @x_out                  ; another selector: consumed
                LDA     _conScratch0
                CLC
                ADC     #3
                CMP     _conTmp0
                BCS     @x_out                  ; 2 without r;g;b
                LDA     _conScratch0
                INC
                JSR     _Vt_ReadParam
                STA     _conScratch1            ; r
                LDA     _conScratch0
                INC
                INC
                JSR     _Vt_ReadParam
                STA     _conScratch2            ; g
                LDA     _conScratch0
                CLC
                ADC     #3
                STA     _conScratch0            ; consumed through b
                JSR     _Vt_ReadParam
                STA     _conScratch3            ; b
                BRA     @x_fold
@x_256          LDA     _conScratch0
                INC
                CMP     _conTmp0
                BCS     @x_out                  ; 5 without its index
                STA     _conScratch0            ; consumed through the index
                JSR     _Vt_ReadParam
                AND     #$00FF
                CMP     #16
                BCC     @x_store                ; 0..15: the index itself
                JSR     _Vt_Rgb256
@x_fold         LDA     1,S                     ; the saved P
                LSR                             ; C = foreground / background
                BCS     @x_bg
                JSR     _Vt_RgbFg
                BRA     @x_store
@x_bg           JSR     _Vt_RgbBg
@x_store        PLP                             ; M=1, and the carry
                MX      %10
                BCS     @x_stBg
                STA    |CON_VT_STATE+VT_SGR_FG
                RTS
@x_stBg         STA    |CON_VT_STATE+VT_SGR_BG
                RTS
@x_out          PLP
                MX      %10
                RTS

;------------------------------------------------------------------------------
; _Vt_Rgb256 - A = 16..255 -> _conScratch1-3 = r, g, b: Linux rgb_from_256.
; 16..231, i = A-16: r = i/36, g = (i/6)%6, b = i%6, each level "* 255 / 6";
; 232..255: all three A*10 - 2312.  M=0; clobbers X, Y.
;------------------------------------------------------------------------------
_Vt_Rgb256      MX      %00
                CMP     #232
                BCS     @r_grey
                SEC
                SBC     #16                     ; i
                LDX     #0
@r_r            CMP     #36
                BCC     @r_rOk
                SBC     #36                     ; C is set
                INX
                INX
                BRA     @r_r
@r_rOk          PHA                             ; i % 36
                LDA     _Vt_CubeLvl,X
                STA     _conScratch1            ; r
                PLA
                LDX     #0
@r_g            CMP     #6
                BCC     @r_gOk
                SBC     #6
                INX
                INX
                BRA     @r_g
@r_gOk          ASL                             ; i % 6, as a word index
                TAY
                LDA     _Vt_CubeLvl,X
                STA     _conScratch2            ; g
                LDA     _Vt_CubeLvl,Y
                STA     _conScratch3            ; b
                RTS
@r_grey         STA     _conScratch1
                ASL
                ASL                             ; C clear: A < 1024
                ADC     _conScratch1            ; *5
                ASL                             ; *10
                SEC
                SBC     #2312
                STA     _conScratch1
                STA     _conScratch2
                STA     _conScratch3
                RTS
_Vt_CubeLvl     DA      0,42,85,127,170,212     ; k * 255 / 6

;------------------------------------------------------------------------------
; _Vt_RgbFg - _conScratch1-3 = r, g, b -> A = ANSI index: Linux
; rgb_foreground.  A component above half the largest sets its hue bit (red
; 1, green 2, blue 4, ECMA-48 order); hue 7 with the largest at or below $55
; is dark grey (8); the largest above $AA is the bright half.  M=0.
; _Vt_RgbBg - the same -> A: rgb_background, "For backgrounds, err on the
; dark side": bit 7 of each component, eight colours.  M=0.
;------------------------------------------------------------------------------
_Vt_RgbFg       MX      %00
                LDA     _conScratch1
                CMP     _conScratch2
                BCS     @f_m1
                LDA     _conScratch2
@f_m1           CMP     _conScratch3
                BCS     @f_m2
                LDA     _conScratch3
@f_m2           STA     _conTmp1                ; max
                LSR
                STA     _conTmp2                ; max / 2
                STZ     _conScratch4            ; hue
                CMP     _conScratch1
                BCS     @f_nr                   ; r <= max/2
                LDA     #1
                TSB     _conScratch4
@f_nr           LDA     _conTmp2
                CMP     _conScratch2
                BCS     @f_ng
                LDA     #2
                TSB     _conScratch4
@f_ng           LDA     _conTmp2
                CMP     _conScratch3
                BCS     @f_nb
                LDA     #4
                TSB     _conScratch4
@f_nb           LDA     _conTmp1
                CMP     #$56
                BCS     @f_notDim               ; max > $55
                LDA     _conScratch4
                CMP     #7
                BNE     @f_hue
                LDA     #8                      ; hue 7, dim: dark grey
                RTS
@f_notDim       CMP     #$AB
                BCC     @f_hue                  ; max <= $AA
                LDA     _conScratch4
                ORA     #8                      ; the bright half
                RTS
@f_hue          LDA     _conScratch4
                RTS

_Vt_RgbBg       MX      %00
                STZ     _conScratch4
                LDA     _conScratch1
                AND     #$80
                BEQ     @g_nr
                LDA     #1
                TSB     _conScratch4
@g_nr           LDA     _conScratch2
                AND     #$80
                BEQ     @g_ng
                LDA     #2
                TSB     _conScratch4
@g_ng           LDA     _conScratch3
                AND     #$80
                BEQ     @g_nb
                LDA     #4
                TSB     _conScratch4
@g_nb           LDA     _conScratch4
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_IND - ESC D. Cursor down; scroll region up if past bottom.
;------------------------------------------------------------------------------
_Vt_Handle_IND  JMP     Con_IndexDown

;------------------------------------------------------------------------------
; _Vt_Handle_RI - ESC M. Cursor up; scroll region down if above top.
;------------------------------------------------------------------------------
_Vt_Handle_RI   JMP     Con_ReverseIndex

;------------------------------------------------------------------------------
; _Vt_Handle_NEL - ESC E. Newline (CR + LF).
;------------------------------------------------------------------------------
_Vt_Handle_NEL  JMP     Con_CR

;------------------------------------------------------------------------------
; _Vt_Handle_RIS - ESC c. Reset to initial state.  The SGR state Con_VtReset
; resets is applied, so the colours return to the console's default pair;
; the pair itself stays, as Linux reset_terminal leaves vc_def_color (only
; vc_init sets it).
;------------------------------------------------------------------------------
_Vt_Handle_RIS  JSR     Con_VtReset
                JSR     _Vt_ApplySgr
                JSR     Con_Clear
                JMP     Con_RenderAll

;------------------------------------------------------------------------------
; _Vt_Handle_DECSTBM - CSI top;bot r. Set scroll region.
; Empty/zero params → reset to full screen.
; 1-based input; stores 0-based values in VT_SR_TOP/VT_SR_BOT.
; Homes cursor (per VT100 spec).
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_DECSTBM MX   %00                     ; caller convention: enter at M=0
                ; Read top (default = 1)
                LDA     #0
                LDX     #1
                JSR     _Vt_ReadParamDefault
                SEC
                SBC     #1                      ; 0-based
                CMP     _Con_VisRows
                BCC     @stbm_topOk
                LDA     _Con_VisRowsM1
@stbm_topOk     STA     _conScratch0            ; top
                ; Read bot (default = VisRows — which is 25, i.e. means row 24 after -1)
                LDA     #1
                LDX     _Con_VisRows
                JSR     _Vt_ReadParamDefault
                SEC
                SBC     #1                      ; 0-based
                CMP     _Con_VisRows
                BCC     @stbm_botOk
                LDA     _Con_VisRowsM1
@stbm_botOk     STA     _conScratch1            ; bot
                ; Validate top < bot. If not, restore full-screen region.
                LDA     _conScratch0
                CMP     _conScratch1
                BCC     @stbm_storeValid
                ; Invalid: reset to full screen (0..VisRowsM1)
                LDA     #0
                STA     _conScratch0
                LDA     _Con_VisRowsM1
                STA     _conScratch1
@stbm_storeValid
                SEP     #$20
                LDA     _conScratch0
                STA    |CON_VT_STATE+VT_SR_TOP
                LDA     _conScratch1
                STA    |CON_VT_STATE+VT_SR_BOT
                REP     #$20
                ; Home cursor (row 0, col 0)
                LDA     #0
                STA    |CON_VT_STATE+VT_CUR_ROW
                STA    |CON_VT_STATE+VT_CUR_COL
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_SU - CSI n S. Scroll up n lines in region (default 1).
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_SU
                LDA     #0
                LDX     #1
                JSR     _Vt_ReadParamDefault
                AND     #$00FF
                BEQ     @su_done                ; n=0: nothing to do
                TAX                             ; X = count
@su_L           PHX
                JSR     Con_ScrollRegionUp
                PLX
                DEX
                BNE     @su_L
@su_done        RTS

;------------------------------------------------------------------------------
; _Vt_Handle_SD - CSI n T. Scroll down n lines in region (default 1).
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_SD
                LDA     #0
                LDX     #1
                JSR     _Vt_ReadParamDefault
                AND     #$00FF
                BEQ     @sd_done
                TAX
@sd_L           PHX
                JSR     Con_ScrollRegionDown
                PLX
                DEX
                BNE     @sd_L
@sd_done        RTS

;------------------------------------------------------------------------------
; _Vt_Handle_SetMode - CSI Pn h or CSI ? Pn h.
; Public modes not supported in v1; private modes route to _Vt_SetPrivateMode.
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_SetMode
                SEP     #$20
                LDA    |CON_VT_STATE+VT_PRIVATE
                CMP     #'?'
                BNE     @sm_public
                REP     #$20
                JMP     _Vt_SetPrivateMode
@sm_public      REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_ResetMode - CSI Pn l or CSI ? Pn l.
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_ResetMode
                SEP     #$20
                LDA    |CON_VT_STATE+VT_PRIVATE
                CMP     #'?'
                BNE     @rm_public
                REP     #$20
                JMP     _Vt_ResetPrivateMode
@rm_public      REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_SetPrivateMode - read param 0, act based on value.
; Supported: 7 (DECAWM), 25 (DECTCEM), 1049 (altscreen enter).
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_SetPrivateMode
                LDA     #0
                LDX     #0
                JSR     _Vt_ReadParamDefault    ; A = 16-bit param (or default)
                AND     #$00FF                  ; params 7/25 fit in 8 bits
                CMP     #7
                BEQ     @spm_awm
                CMP     #25
                BEQ     @spm_tcem
                ; Full 16-bit compare for 1049 ($0419).
                ; (Re-read as 16-bit; we just truncated.)
                LDA     #0
                LDX     #0
                JSR     _Vt_ReadParamDefault
                CMP     #1049
                BEQ     @spm_alt
                RTS
@spm_awm
                SEP     #$20
                LDA     #1
                STA    |CON_VT_STATE+VT_AUTOWRAP
                REP     #$20
                RTS
@spm_tcem
                SEP     #$20
                LDA     #1
                STA    |CON_VT_STATE+VT_CURSOR_VISIBLE
                REP     #$20
                RTS
@spm_alt
                JMP     Con_EnterAltScreen

;------------------------------------------------------------------------------
; _Vt_ResetPrivateMode - read param 0, act based on value.
; Supported: 7 (DECAWM), 25 (DECTCEM), 1049 (altscreen exit).
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_ResetPrivateMode
                LDA     #0
                LDX     #0
                JSR     _Vt_ReadParamDefault
                AND     #$00FF
                CMP     #7
                BEQ     @rpm_awm
                CMP     #25
                BEQ     @rpm_tcem
                LDA     #0
                LDX     #0
                JSR     _Vt_ReadParamDefault
                CMP     #1049
                BEQ     @rpm_alt
                RTS
@rpm_awm
                SEP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_AUTOWRAP
                REP     #$20
                RTS
@rpm_tcem
                SEP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_CURSOR_VISIBLE
                REP     #$20
                RTS
@rpm_alt
                JMP     Con_ExitAltScreen

;------------------------------------------------------------------------------
; _Vt_Handle_HTS - ESC H. Set tab stop at current cursor column.
; Entry/exit: M=0 (called from _Vt_DispatchEsc via REP/SEP bracket).
;------------------------------------------------------------------------------
_Vt_Handle_HTS
                SEP     #$20
                LDA    |CON_VT_STATE+VT_CUR_COL              ; col (8-bit value in low byte)
                STA     _conTmp0                ; save col
                ; Compute byte index (col >> 3), 16-bit clean.
                REP     #$20
                AND     #$00FF
                LSR
                LSR
                LSR                             ; col >> 3 = byte index (0..9)
                TAX                             ; X = 16-bit byte index
                SEP     #$20
                LDA     _conTmp0
                AND     #$07                    ; col & 7 = bit index
                ; Force Y high byte = 0.
                REP     #$20
                AND     #$00FF
                TAY                             ; Y = 16-bit bit index (clean)
                SEP     #$20
                LDA     #1
@hts_shift      CPY     #0
                BEQ     @hts_done_shift
                ASL
                DEY
                BRA     @hts_shift
@hts_done_shift ORA     |CON_VT_STATE+VT_TAB_STOPS,X    ; set the bit
                STA    |CON_VT_STATE+VT_TAB_STOPS,X
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_TBC - CSI n g. Clear tab stop(s).
;   n=0 (default 0): clear stop at current col.
;   n=3: clear all stops.
; Entry/exit: M=0.
;------------------------------------------------------------------------------
_Vt_Handle_TBC
                LDA     #0
                LDX     #0
                JSR     _Vt_ReadParamDefault    ; A = 16-bit param (0 if missing/zero)
                AND     #$00FF
                CMP     #3
                BEQ     @tbc_all
                ; n=0: clear stop at current col.
                SEP     #$20
                LDA    |CON_VT_STATE+VT_CUR_COL
                STA     _conTmp0                ; save col
                REP     #$20
                AND     #$00FF
                LSR
                LSR
                LSR                             ; col >> 3 = byte index
                TAX                             ; X = 16-bit byte index (clean)
                SEP     #$20
                LDA     _conTmp0
                AND     #$07                    ; col & 7 = bit index
                REP     #$20
                AND     #$00FF
                TAY                             ; Y = 16-bit bit index (clean)
                SEP     #$20
                LDA     #1
@tbc_shift      CPY     #0
                BEQ     @tbc_done_shift
                ASL
                DEY
                BRA     @tbc_shift
@tbc_done_shift EOR     #$FF                    ; invert mask to clear the bit
                AND     |CON_VT_STATE+VT_TAB_STOPS,X
                STA    |CON_VT_STATE+VT_TAB_STOPS,X
                REP     #$20
                RTS
@tbc_all
                ; Clear all 10 tab-stop bytes.
                SEP     #$20
                LDA     #0
                LDX     #0
@tbc_clr_L      STA    |CON_VT_STATE+VT_TAB_STOPS,X
                INX
                CPX     #10
                BCC     @tbc_clr_L
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_Charset_G0 - ESC ( <final>. Set G0 charset.
;   '0' = DEC Special Graphics (enables char translation in Con_PutChar)
;   'B' = US-ASCII (default, no translation)
; Entry/exit: M=0. A = final byte (16-bit, high byte already masked by caller).
;------------------------------------------------------------------------------
_Vt_Handle_Charset_G0
                CMP     #'0'
                BEQ     @g0_dec
                CMP     #'B'
                BEQ     @g0_ascii
                RTS                             ; unknown: ignore
@g0_dec
                SEP     #$20
                LDA     #1
                STA    |CON_VT_STATE+VT_G0_CHARSET
                REP     #$20
                RTS
@g0_ascii
                SEP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_G0_CHARSET
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_Charset_G1 - ESC ) <final>. Set G1 charset.
;   '0' = DEC Special Graphics
;   'B' = US-ASCII (default)
; Entry/exit: M=0. A = final byte (16-bit, high byte already masked by caller).
;------------------------------------------------------------------------------
_Vt_Handle_Charset_G1
                CMP     #'0'
                BEQ     @g1_dec
                CMP     #'B'
                BEQ     @g1_ascii
                RTS                             ; unknown: ignore
@g1_dec
                SEP     #$20
                LDA     #1
                STA    |CON_VT_STATE+VT_G1_CHARSET
                REP     #$20
                RTS
@g1_ascii
                SEP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_G1_CHARSET
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_Handle_DSR - CSI n. Device Status Report. No pty → just RTS.
;------------------------------------------------------------------------------
_Vt_Handle_DSR  RTS

;------------------------------------------------------------------------------
; _Vt_Handle_DA - CSI c. Device Attributes. No pty → just RTS.
;------------------------------------------------------------------------------
_Vt_Handle_DA   RTS

;==============================================================================
; END console_vthandler.s
;==============================================================================

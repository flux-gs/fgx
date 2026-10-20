                MX      %10                 ; Merlin default: M=1 (8-bit A), X=0 (16-bit X).
;==============================================================================
; console_vt.s - VT parser state machine (Paul Williams VT500 subset).
;
; Public:
;   Con_Write     A (low byte) = byte to process.
;   Con_WriteBuf  _conStrPtr = byte pointer (bank $02 via DBR), X = length.
;   Con_VtReset   Reset parser to GROUND + clear SgrState defaults.
;
; CPU mode convention for this file:
;   Con_Write / state-machine labels: M=1 (8-bit A, SEP #$20).
;   Sub-blocks that need 16-bit ops: REP #$20 briefly, then SEP #$20.
;   External calls (Con_PutChar, _Vt_DispatchCsi): M=0 entry expected — wrap
;   JSR with REP #$20 / SEP #$20 AT THE CALL SITE.
;
; Each state label starts with `MX %10` so Merlin's static tracking lines up
; with runtime (the file has many REP/SEP brackets that confuse Merlin when
; branches skip past them — MX directives force the view to match).
;==============================================================================

;------------------------------------------------------------------------------
; Con_Write - feed one byte through the parser.
; Input: A (low byte) = byte. Preserves no registers.
;
; MX:       Caller %10 expected by directive; routine internally normalizes
;           via REP #$10 / SEP #$20 and restores caller's M/X via PHP/PLP.
;           Callable from any M/X.
; Clobbers: A, X, Y.  Caller MUST wrap X in PHX/PLX if it must survive
;           — Con_Write's parser/rasterizer uses X heavily.
;           _conScratch0..7, _conTmp*, _conStrPtr/_conFontPtr (console-
;           internal).  _conCurRow / _conCurCol updated as cursor moves.
;------------------------------------------------------------------------------
Con_Write       MX      %10
                PHP                         ; save caller's P (M/X/C/etc.)
                REP     #$10                ; normalize X=0 — body is MX %10
                MX      %00                 ;   (tell Merlin before the SEP below)
                SEP     #$20                ; M=1 now — byte ops
                MX      %10
                STA     _conScratch0        ; save byte (low 8 bits)
                LDA    |CON_VT_STATE+VT_STATE
                CMP     #VT_S_GROUND
                BEQ     @vw_ground
                CMP     #VT_S_ESCAPE
                BEQ     @vw_dEscape
                CMP     #VT_S_ESC_INT
                BEQ     @vw_dEscInt
                CMP     #VT_S_CSI_ENTRY
                BEQ     @vw_dCsiEntry
                CMP     #VT_S_CSI_PARAM
                BEQ     @vw_dCsiParam
                CMP     #VT_S_CSI_INT
                BEQ     @vw_dCsiInt
                CMP     #VT_S_CSI_IGNORE
                BEQ     @vw_dCsiIgnore
                JMP     @vw_resetToGround
@vw_dEscape     JMP     @vw_escape
@vw_dEscInt     JMP     @vw_escInt
@vw_dCsiEntry   JMP     @vw_csiEntry
@vw_dCsiParam   JMP     @vw_csiParam
@vw_dCsiInt     JMP     @vw_csiInt
@vw_dCsiIgnore  JMP     @vw_csiIgnore

;------------------------------------------------------------------------------
; GROUND: printable -> Con_PutChar; C0 -> execute; ESC -> ESCAPE.
;------------------------------------------------------------------------------
@vw_ground      MX      %10
                LDA     _conScratch0
                CMP     #$1B                ; ESC
                BEQ     @vw_toEscape
                CMP     #$20
                BCC     @vw_c0              ; C0 controls
                CMP     #$7F                ; DEL
                BEQ     @vw_gDone
                REP     #$20                ; → M=0 for Con_PutChar call
                AND     #$00FF
                JSR     Con_PutChar
                PLP                         ; restore caller's P (M/X/C/etc.)
                RTS

@vw_c0          MX      %10
                ; C0 controls in GROUND.
                CMP     #$07                ; BEL -> ring speaker
                BEQ     @vw_bel
                CMP     #$09                ; HT: tab
                BEQ     @vw_ht
                CMP     #$0E                ; SO - shift out to G1
                BEQ     @vw_so
                CMP     #$0F                ; SI - shift in to G0
                BEQ     @vw_si
                ; BS/LF/CR/etc: pass through to Con_PutChar.
                REP     #$20
                LDA     _conScratch0
                AND     #$00FF
                JSR     Con_PutChar
                PLP                         ; restore caller's P (M/X/C/etc.)
                RTS
@vw_bel         MX      %10
                JSR     Con_Beep
                BRA     @vw_gDone
@vw_ht          MX      %10
                JSR     _Vt_Execute_HT
                BRA     @vw_gDone
@vw_so          MX      %10
                LDA     #1
                STA    |CON_VT_STATE+VT_GL
                BRA     @vw_gDone
@vw_si          MX      %10
                LDA     #0
                STA    |CON_VT_STATE+VT_GL
                BRA     @vw_gDone

@vw_toEscape    MX      %10
                LDA     #VT_S_ESCAPE
                STA    |CON_VT_STATE+VT_STATE
@vw_gDone       PLP                         ; restore caller's P (M/X/C/etc.)
                RTS

;------------------------------------------------------------------------------
; ESCAPE state (after seeing ESC in GROUND).
;------------------------------------------------------------------------------
@vw_escape      MX      %10
                ; Clear intermediate bytes so a stale VT_INT1 from a previous
                ; ESC sequence doesn't mis-fire the charset-G0 check.
                LDA     #0
                STA    |CON_VT_STATE+VT_INT1
                STA    |CON_VT_STATE+VT_INT2
                LDA     _conScratch0
                CMP     #$5B                ; '['
                BEQ     @vw_esc_toCsi
                CMP     #$20
                BCC     @vw_esc_c0          ; C0 control: abort + re-feed
                CMP     #$30
                BCC     @vw_esc_collect     ; $20-$2F intermediate
                CMP     #$7F
                BCC     @vw_esc_final       ; $30-$7E final byte -> dispatch
                JMP     @vw_toGround        ; $7F: discard
@vw_esc_final   MX      %10
                JSR     _Vt_DispatchEsc
                JMP     @vw_toGround
@vw_esc_toCsi   MX      %10
                ; Clear param buffer; enter CSI_ENTRY.
                LDA     #0
                STA    |CON_VT_STATE+VT_NPARAMS
                STA    |CON_VT_STATE+VT_PARAM_CUR
                STA    |CON_VT_STATE+VT_INT1
                STA    |CON_VT_STATE+VT_INT2
                STA    |CON_VT_STATE+VT_PRIVATE
                STA    |CON_VT_STATE+VT_PARAMS+0
                STA    |CON_VT_STATE+VT_PARAMS+1
                STA    |CON_VT_STATE+VT_PARAMS+2
                STA    |CON_VT_STATE+VT_PARAMS+3
                LDA     #VT_S_CSI_ENTRY
                STA    |CON_VT_STATE+VT_STATE
                JMP     @vw_done
@vw_esc_collect MX      %10
                LDA     _conScratch0
                STA    |CON_VT_STATE+VT_INT1
                LDA     #VT_S_ESC_INT
                STA    |CON_VT_STATE+VT_STATE
                JMP     @vw_done
@vw_esc_c0      MX      %10
                LDA     #VT_S_GROUND
                STA    |CON_VT_STATE+VT_STATE
                JMP     @vw_ground

;------------------------------------------------------------------------------
; ESC_INT state (intermediate byte in ESC sequence).
;------------------------------------------------------------------------------
@vw_escInt      MX      %10
                LDA     _conScratch0
                CMP     #$30
                BCC     @vw_escInt_collect
                CMP     #$7F
                BCC     @vw_escInt_final
                JMP     @vw_toGround
@vw_escInt_final MX     %10
                JSR     _Vt_DispatchEsc
                JMP     @vw_toGround
@vw_escInt_collect MX   %10
                LDA     _conScratch0
                STA    |CON_VT_STATE+VT_INT2
                JMP     @vw_done

;------------------------------------------------------------------------------
; CSI_ENTRY state (first byte after ESC [).
;------------------------------------------------------------------------------
@vw_csiEntry    MX      %10
                LDA     _conScratch0
                CMP     #$20
                BCC     @vw_csiE_tg         ; C0: reset
                CMP     #$30
                BCC     @vw_csiE_int
                CMP     #$3A                ; digit 0..9
                BCC     @vw_csiE_digit
                CMP     #$3B                ; ';'
                BEQ     @vw_csiE_semi
                CMP     #$3C                ; '<'
                BCC     @vw_csiE_tg         ; $3A: ignore
                CMP     #$40
                BCC     @vw_csiE_priv
                CMP     #$7F
                BCS     @vw_csiE_tg
                ; $40-$7E: CSI final (no params)
                JSR     _Vt_DispatchCsi
@vw_csiE_tg     JMP     @vw_toGround
@vw_csiE_digit  MX      %10
                LDA     _conScratch0
                SEC
                SBC     #$30                ; digit 0..9
                STA    |CON_VT_STATE+VT_PARAMS+0
                LDA     #0
                STA    |CON_VT_STATE+VT_PARAMS+1
                LDA     #1
                STA    |CON_VT_STATE+VT_NPARAMS
                LDA     #0
                STA    |CON_VT_STATE+VT_PARAM_CUR
                LDA     #VT_S_CSI_PARAM
                STA    |CON_VT_STATE+VT_STATE
                JMP     @vw_done
@vw_csiE_semi   MX      %10
                ; ';' with no prior digit: 2 params, both 0.
                LDA     #0
                STA    |CON_VT_STATE+VT_PARAMS+0
                STA    |CON_VT_STATE+VT_PARAMS+1
                STA    |CON_VT_STATE+VT_PARAMS+2
                STA    |CON_VT_STATE+VT_PARAMS+3
                LDA     #2
                STA    |CON_VT_STATE+VT_NPARAMS
                LDA     #1
                STA    |CON_VT_STATE+VT_PARAM_CUR
                LDA     #VT_S_CSI_PARAM
                STA    |CON_VT_STATE+VT_STATE
                JMP     @vw_done
@vw_csiE_priv   MX      %10
                LDA     _conScratch0
                STA    |CON_VT_STATE+VT_PRIVATE
                LDA     #VT_S_CSI_PARAM
                STA    |CON_VT_STATE+VT_STATE
                JMP     @vw_done
@vw_csiE_int    MX      %10
                LDA     _conScratch0
                STA    |CON_VT_STATE+VT_INT1
                LDA     #VT_S_CSI_INT
                STA    |CON_VT_STATE+VT_STATE
                JMP     @vw_done

;------------------------------------------------------------------------------
; CSI_PARAM state (accumulating params).
;------------------------------------------------------------------------------
@vw_csiParam    MX      %10
                LDA     _conScratch0
                CMP     #$20
                BCC     @vw_csiP_tg         ; C0: reset to GROUND
                CMP     #$30
                BCC     @vw_csiP_int
                CMP     #$3A
                BCC     @vw_csiP_digit
                CMP     #$3B
                BEQ     @vw_csiP_semi
                CMP     #$40
                BCC     @vw_csiP_bad
                CMP     #$7F
                BCS     @vw_csiP_tg
                ; $40-$7E final -> dispatch
                JSR     _Vt_DispatchCsi
@vw_csiP_tg     JMP     @vw_toGround

@vw_csiP_bad    MX      %10
                LDA     #VT_S_CSI_IGNORE
                STA    |CON_VT_STATE+VT_STATE
                JMP     @vw_done
@vw_csiP_int    MX      %10
                LDA     _conScratch0
                STA    |CON_VT_STATE+VT_INT1
                LDA     #VT_S_CSI_INT
                STA    |CON_VT_STATE+VT_STATE
                JMP     @vw_done
@vw_csiP_semi   MX      %10
                LDA     |CON_VT_STATE+VT_PARAM_CUR
                INC
                CMP     #16
                BCC     @vw_csiP_curOk
                LDA     #15
@vw_csiP_curOk  STA    |CON_VT_STATE+VT_PARAM_CUR
                LDA     |CON_VT_STATE+VT_PARAM_CUR
                INC
                STA     _conScratch1        ; cur + 1
                LDA     |CON_VT_STATE+VT_NPARAMS
                CMP     _conScratch1
                BCS     @vw_csiP_npOk
                LDA     _conScratch1
                STA    |CON_VT_STATE+VT_NPARAMS
@vw_csiP_npOk   MX      %10
                ; Zero-init params[cur] (16-bit).  The byte offset is formed
                ; 16-bit: an 8-bit LDA leaves B stale, and TAX with X=16 moves
                ; B:A, so the index would carry whatever B held.
                REP     #$20
                MX      %00
                LDA     |CON_VT_STATE+VT_PARAM_CUR
                AND     #$00FF
                ASL
                TAX                         ; X = param_cur * 2
                SEP     #$20
                MX      %10
                LDA     #0                  ; low byte 0
                STA    |CON_VT_STATE+VT_PARAMS,X
                INX
                STA    |CON_VT_STATE+VT_PARAMS,X
                JMP     @vw_done
@vw_csiP_digit  MX      %10
                ; params[cur] = min(255, params[cur] * 10 + digit)
                ; All ops in M=1 (8-bit); values > 255 saturate — fine for Plan 2.
                LDA     _conScratch0
                SEC
                SBC     #$30
                AND     #$0F
                STA     _conScratch1        ; digit
                ; Compute byte offset X = param_cur * 2, 16-bit for the reason
                ; the zero-init arm above gives.
                REP     #$20
                MX      %00
                LDA     |CON_VT_STATE+VT_PARAM_CUR
                AND     #$00FF
                ASL
                TAX
                SEP     #$20
                MX      %10
                ; A = params[cur] low byte * 10 + digit (saturating).
                LDA    |CON_VT_STATE+VT_PARAMS,X
                STA     _conScratch2        ; current param low byte
                ASL
                STA     _conScratch3        ; *2
                ASL
                ASL                         ; *8
                CLC
                ADC     _conScratch3        ; *8 + *2 = *10
                CLC
                ADC     _conScratch1        ; + digit
                STA    |CON_VT_STATE+VT_PARAMS,X
                INX
                LDA     #0                  ; clear high byte of 16-bit param
                STA    |CON_VT_STATE+VT_PARAMS,X
                JMP     @vw_done

;------------------------------------------------------------------------------
; CSI_INT state.
;------------------------------------------------------------------------------
@vw_csiInt      MX      %10
                LDA     _conScratch0
                CMP     #$20
                BCC     @vw_toGround
                CMP     #$30
                BCC     @vw_csiInt_collect
                CMP     #$40
                BCC     @vw_csiInt_bad
                CMP     #$7F
                BCS     @vw_toGround
                JSR     _Vt_DispatchCsi
                JMP     @vw_toGround
@vw_csiInt_collect MX   %10
                LDA     _conScratch0
                STA    |CON_VT_STATE+VT_INT2
                JMP     @vw_done
@vw_csiInt_bad  MX      %10
                LDA     #VT_S_CSI_IGNORE
                STA    |CON_VT_STATE+VT_STATE
                JMP     @vw_done

;------------------------------------------------------------------------------
; CSI_IGNORE state.
;------------------------------------------------------------------------------
@vw_csiIgnore   MX      %10
                LDA     _conScratch0
                CMP     #$40
                BCC     @vw_done
                CMP     #$7F
                BCS     @vw_done
                JMP     @vw_toGround

@vw_toGround    MX      %10
@vw_resetToGround
                LDA     #VT_S_GROUND
                STA    |CON_VT_STATE+VT_STATE
@vw_done        PLP                         ; restore caller's P (M/X/C/etc.)
                RTS

;------------------------------------------------------------------------------
; Con_WriteBuf - feed N bytes through the parser.
; Input: _conStrPtr = ptr (bank $02 via DBR), X = length.
;------------------------------------------------------------------------------
Con_WriteBuf    MX      %00
                PHP                         ; save caller's P (M/X/C/etc.)
                REP     #$30                ; normalize M=0, X=0 — body is MX %00
                MX      %00
                CPX     #0
                BEQ     @wb_done
                LDY     #0
@wb_L
                SEP     #$20
                LDA     (_conStrPtr),Y
                REP     #$20
                AND     #$00FF
                PHX
                PHY
                JSR     Con_Write
                PLY
                PLX
                INY
                DEX
                BNE     @wb_L
@wb_done        PLP                         ; restore caller's P (M/X/C/etc.)
                RTS

;------------------------------------------------------------------------------
; Con_VtReset - reset parser + SgrState.
;------------------------------------------------------------------------------
Con_VtReset     MX      %10
                SEP     #$20
                LDA     #VT_S_GROUND
                STA    |CON_VT_STATE+VT_STATE
                LDA     #0
                STA    |CON_VT_STATE+VT_INT1
                STA    |CON_VT_STATE+VT_INT2
                STA    |CON_VT_STATE+VT_PRIVATE
                STA    |CON_VT_STATE+VT_NPARAMS
                STA    |CON_VT_STATE+VT_PARAM_CUR
                STA    |CON_VT_STATE+VT_SGR_FLAGS
                LDA     #$FF
                STA    |CON_VT_STATE+VT_SGR_FG
                STA    |CON_VT_STATE+VT_SGR_BG
                STA    |CON_VT_STATE+VT_ROW_PALETTE
                ; Default scroll region = full screen
                LDA     #0
                STA    |CON_VT_STATE+VT_SR_TOP
                LDA     _Con_VisRowsM1      ; low byte = 24 (DP word, we only want low byte)
                STA    |CON_VT_STATE+VT_SR_BOT
                LDA     #0
                STA    |CON_VT_STATE+VT_G0_CHARSET
                STA    |CON_VT_STATE+VT_G1_CHARSET
                STA    |CON_VT_STATE+VT_GL
                ; VT_SAVED_* defaults — match the "fresh boot" state that a
                ; DECRC before any DECSC should effectively roll back to,
                ; not whatever garbage was in RAM.
                STA    |CON_VT_STATE+VT_SAVED_ROW   ; 0 = home row
                STA    |CON_VT_STATE+VT_SAVED_COL   ; 0 = home col
                STA    |CON_VT_STATE+VT_SAVED_G0    ; ASCII
                STA    |CON_VT_STATE+VT_SAVED_G1    ; ASCII
                STA    |CON_VT_STATE+VT_SAVED_GL    ; G0 active
                LDA     #1
                STA    |CON_VT_STATE+VT_SAVED_ATTR  ; $01 matches _conAttr default (visible)
                LDA     #$FF
                STA    |CON_VT_STATE+VT_SAVED_PAL   ; $FF = no auto-palette override
                LDA     #1
                STA    |CON_VT_STATE+VT_CURSOR_VISIBLE
                STA    |CON_VT_STATE+VT_AUTOWRAP
                LDA     #0
                STA    |CON_VT_STATE+VT_CURS_RENDERED
                ; Initialize default tab stops (every 8 cols: 8, 16, 24, ... 72).
                ; Byte N (N=1..9) of the 10-byte bitmap covers cols N*8..N*8+7.
                ; We want bit 0 of bytes 1..9 set (representing cols 8, 16, ...).
                LDA     #0
                STA    |CON_VT_STATE+VT_TAB_STOPS+0
                LDA     #1                  ; bit 0 = col at byte's lowest col
                STA    |CON_VT_STATE+VT_TAB_STOPS+1
                STA    |CON_VT_STATE+VT_TAB_STOPS+2
                STA    |CON_VT_STATE+VT_TAB_STOPS+3
                STA    |CON_VT_STATE+VT_TAB_STOPS+4
                STA    |CON_VT_STATE+VT_TAB_STOPS+5
                STA    |CON_VT_STATE+VT_TAB_STOPS+6
                STA    |CON_VT_STATE+VT_TAB_STOPS+7
                STA    |CON_VT_STATE+VT_TAB_STOPS+8
                STA    |CON_VT_STATE+VT_TAB_STOPS+9
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_Execute_HT - horizontal tab. Advance cursor to next set tab stop,
; or clamp at rightmost col if no stop found beyond current col.
; Entry/exit: M=1 (caller is Con_Write in M=1).
;------------------------------------------------------------------------------
_Vt_Execute_HT  MX      %10
                LDA    |CON_VT_STATE+VT_CUR_COL
                STA     _conTmp0                ; search col (advances each step)
@ht_next        INC     _conTmp0
                LDA     _conTmp0
                CMP     _Con_RowBytes
                BCS     @ht_clamp
                ; Compute byte index: REP to 16-bit, AND to zero-extend, then LSR *3.
                STA     _conTmp1                ; save col (8-bit value in low byte)
                REP     #$20
                AND     #$00FF
                LSR
                LSR
                LSR                             ; col >> 3 = byte index (0..9)
                TAX                             ; X = 16-bit byte index (clean)
                SEP     #$20
                LDA     _conTmp1
                AND     #$07                    ; col & 7 = bit index (0..7)
                ; Force bit index into Y with zero-extended high byte.
                REP     #$20
                AND     #$00FF
                TAY                             ; Y = 16-bit bit index (clean)
                SEP     #$20
                LDA     #1
@ht_mask        CPY     #0
                BEQ     @ht_done_mask
                ASL
                DEY
                BRA     @ht_mask
@ht_done_mask   AND     |CON_VT_STATE+VT_TAB_STOPS,X   ; test this col's stop bit
                BEQ     @ht_next                ; bit clear → no stop, try next col
                LDA     _conTmp0
                STA    |CON_VT_STATE+VT_CUR_COL
                RTS
@ht_clamp       MX      %10
                LDA     _Con_RowBytes
                DEC
                STA    |CON_VT_STATE+VT_CUR_COL
                RTS

;------------------------------------------------------------------------------
; _Vt_DispatchEsc - ESC <int> <final>. Called from Con_Write in M=1.
; Wraps handlers (M=0 convention) with REP/SEP brackets.
;------------------------------------------------------------------------------
_Vt_DispatchEsc MX      %10
                ; Stay in M=1 for compares. _conScratch0 is DP word but only
                ; the low byte was stored (state-machine saves as byte), so
                ; 16-bit reads would see stale high byte. M=1 reads low byte.
                LDA    |CON_VT_STATE+VT_INT1
                CMP     #'('
                BEQ     @vde_charset_g0
                CMP     #')'
                BEQ     @vde_charset_g1
                LDA     _conScratch0
                CMP     #'7'
                BEQ     @vde_decsc
                CMP     #'8'
                BEQ     @vde_decrc
                CMP     #'D'
                BEQ     @vde_ind
                CMP     #'M'
                BEQ     @vde_ri
                CMP     #'E'
                BEQ     @vde_nel
                CMP     #'c'
                BEQ     @vde_ris
                CMP     #'H'                    ; HTS: set tab stop at current col
                BEQ     @vde_hts
                RTS
@vde_charset_g0 MX      %10
                LDA     _conScratch0            ; final byte (low 8 of A)
                REP     #$20                    ; → M=0 for handler call
                AND     #$00FF
                JSR     _Vt_Handle_Charset_G0
                SEP     #$20
                RTS
@vde_charset_g1 MX      %10
                LDA     _conScratch0            ; final byte (low 8 of A)
                REP     #$20                    ; → M=0 for handler call
                AND     #$00FF
                JSR     _Vt_Handle_Charset_G1
                SEP     #$20
                RTS
@vde_hts        MX      %10
                REP     #$20
                JSR     _Vt_Handle_HTS
                SEP     #$20
                RTS
@vde_decsc      MX      %10
                REP     #$20
                JSR     _Vt_Handle_DECSC
                SEP     #$20
                RTS
@vde_decrc      MX      %10
                REP     #$20
                JSR     _Vt_Handle_DECRC
                SEP     #$20
                RTS
@vde_ind        MX      %10
                REP     #$20
                JSR     _Vt_Handle_IND
                SEP     #$20
                RTS
@vde_ri         MX      %10
                REP     #$20
                JSR     _Vt_Handle_RI
                SEP     #$20
                RTS
@vde_nel        MX      %10
                REP     #$20
                JSR     _Vt_Handle_NEL
                SEP     #$20
                RTS
@vde_ris        MX      %10
                REP     #$20
                JSR     _Vt_Handle_RIS
                SEP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_DispatchCsi - CSI final byte in _conScratch0. Wraps handler in M=0.
;------------------------------------------------------------------------------
_Vt_DispatchCsi MX      %10
                REP     #$20
                LDA     _conScratch0
                AND     #$00FF
                JSR     _Vt_DispatchCsiByFinal
                SEP     #$20
                RTS

;------------------------------------------------------------------------------
; Con_Beep - fire the system alert tone and briefly flash the screen border.
;
; Called when the VT parser sees BEL ($07) in GROUND state.  Sound itself
; goes through the Sound Tool Set (Sound_Beep → _FFStartSound on generator
; 0) since the Apple II speaker latch path at $E0C030 is unreliable under
; recent MAME builds.  The border flash stays — visual feedback works
; everywhere, including silent emulator runs.
;
; The Sound_Beep call is non-blocking (DOC clocks samples asynchronously),
; so the border flash only needs to last long enough to register visually;
; we keep it short (~half the old toggle-loop duration).
;
; Caller MX any.  Preserves all caller flags via PHP/PLP.
;------------------------------------------------------------------------------
Con_Beep        MX      %00
                PHP

                ; --- Ensoniq-side beep.  Unconditional: the sysbeep setting
                ;     that gated it was early testing scaffolding and went
                ;     with /etc/conmode (2026-09-01).
                REP     #$30
                MX      %00
                JSR     _Sound_BeepImpl         ; same bank: JSR the RTS-terminated
                                                ;   impl, NOT the RTL export wrapper
                REP     #$20
                MX      %00

                ; --- Border flash for visual feedback.
                SEP     #$30
                MX      %11
                LDAL    $E0C034
                STA     _cb_savedBorder
                AND     #$F0                    ; preserve text/bg nibble
                ORA     #$0F                    ; border = white ($F)
                STAL    $E0C034

                ; --- Burn ~40 ms in a tight delay so the flash is visible.
                ;     Per inner iter: DEY(2) + BNE(3) = 5 cyc.
                ;     LDY=$FF → ~1280 cyc inner; LDX=$60 outer → ~78 k cyc
                ;     ≈ 28 ms @ 2.8 MHz.
                LDX     #$60
@cb_outerL      LDY     #$FF
@cb_innerL      DEY
                BNE     @cb_innerL
                DEX
                BNE     @cb_outerL

                ; --- Restore border.
                LDA     _cb_savedBorder
                STAL    $E0C034
                PLP
                RTS

_cb_savedBorder DS      1

;==============================================================================
; END console_vt.s
;==============================================================================

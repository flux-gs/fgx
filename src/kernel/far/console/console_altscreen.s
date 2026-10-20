;==============================================================================
; console_altscreen.s - Alt-screen save/restore for full-screen apps.
;
; Public:
;   Con_EnterAltScreen   Save state + visible 25 CharBuf rows, Con_Clear,
;                        cursor to (0,0), follow off. Caller drives the
;                        screen freely.
;
;   Con_ExitAltScreen    Restore visible 25 CharBuf rows + saved state,
;                        rebuild font tables (alt session may have changed
;                        fg/bg), Con_RenderAll.
;
; State model: one level of save/restore (not stackable). A second
; Con_EnterAltScreen before Exit will overwrite the prior save.
;
; Backup memory layout (all owned by include/memmap.s):
;   CON_ALT_SAVE              saved state words (16 B, bank $02)
;   CON_ALT_CBUF              saved CharBuf[ring rows 0..24] (2 KB, bank $03)
;   CON_ALT_ABUF              saved AttrBuf (25 rows × 80, bank $03)
;
; Limitation: only ring rows 0..24 are preserved. If the alt session
; writes beyond 25 rows (scrolls into the ring), scrollback history in
; rows 25..99 is clobbered and NOT restored. Full CharBuf isolation is
; a Phase 7 concern (needs bank $03 for backup storage).
;==============================================================================

;------------------------------------------------------------------------------
; Con_EnterAltScreen - save state + visible 25 CharBuf rows, clear screen,
; cursor (0,0), follow off.
;------------------------------------------------------------------------------
Con_EnterAltScreen
                ; Save state words
                LDA    |CON_VT_STATE+VT_WRITE_PTR
                STA    |CON_ALT_SAVE+0
                LDA    |CON_VT_STATE+VT_TOP_ROW
                STA    |CON_ALT_SAVE+2
                LDA    |CON_VT_STATE+VT_CUR_ROW
                STA    |CON_ALT_SAVE+4
                LDA    |CON_VT_STATE+VT_CUR_COL
                STA    |CON_ALT_SAVE+6
                SEP     #$20
                LDA    |CON_VT_STATE+VT_FOLLOW
                STA    |CON_ALT_SAVE+8
                LDA    |CON_VT_STATE+VT_FG
                STA    |CON_ALT_SAVE+9
                LDA    |CON_VT_STATE+VT_BG
                STA    |CON_ALT_SAVE+10
                LDA    |CON_VT_STATE+VT_G0_CHARSET
                STA    |CON_ALT_SAVE+11
                LDA    |CON_VT_STATE+VT_G1_CHARSET
                STA    |CON_ALT_SAVE+12
                LDA    |CON_VT_STATE+VT_GL
                STA    |CON_ALT_SAVE+13
                REP     #$20

                ; Snapshot CharBuf[0..1999] -> CON_ALT_CBUF at $038000.
                REP     #$30
                LDX     #$0000              ; src = $030000 CON_CHARBUF
                LDY     #$8000              ; dst = $038000 CON_ALT_CBUF
                LDA     #1999               ; count - 1
_kcm001         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20

                ; Snapshot AttrBuf: $032000 -> $038800 CON_ALT_ABUF.
                REP     #$30
                LDX     #$2000
                LDY     #$8800
                LDA     #1999
_kcm002         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20

                ; Snapshot FgBuf: $034000 -> $039000 CON_ALT_FGBUF.
                REP     #$30
                LDX     #$4000
                LDY     #$9000
                LDA     #1999
_kcm003         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20

                ; Snapshot BgBuf: $036000 -> $039800 CON_ALT_BGBUF.
                REP     #$30
                LDX     #$6000
                LDY     #$9800
                LDA     #1999
_kcm004         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20

                ; Default alt posture
                LDA     #0
                STA    |CON_VT_STATE+VT_CUR_ROW
                STA    |CON_VT_STATE+VT_CUR_COL
                STA    |CON_VT_STATE+VT_TOP_ROW
                SEP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_FOLLOW
                STA    |CON_VT_STATE+VT_G0_CHARSET
                STA    |CON_VT_STATE+VT_G1_CHARSET
                STA    |CON_VT_STATE+VT_GL
                REP     #$20
                JMP     Con_Clear

;------------------------------------------------------------------------------
; Con_ExitAltScreen - restore CharBuf snapshot + state, rebuild font, repaint.
;------------------------------------------------------------------------------
Con_ExitAltScreen
                ; Restore CharBuf[0..1999] from CON_ALT_CBUF at $038000.
                REP     #$30
                LDX     #$8000
                LDY     #$0000
                LDA     #1999
_kcm005         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20

                ; Restore AttrBuf: $038800 -> $032000.
                REP     #$30
                LDX     #$8800
                LDY     #$2000
                LDA     #1999
_kcm006         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20

                ; Restore FgBuf: $039000 -> $034000.
                REP     #$30
                LDX     #$9000
                LDY     #$4000
                LDA     #1999
_kcm007         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20

                ; Restore BgBuf: $039800 -> $036000.
                REP     #$30
                LDX     #$9800
                LDY     #$6000
                LDA     #1999
_kcm008         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20

                ; Restore state
                LDA    |CON_ALT_SAVE+0
                STA    |CON_VT_STATE+VT_WRITE_PTR
                LDA    |CON_ALT_SAVE+2
                STA    |CON_VT_STATE+VT_TOP_ROW
                LDA    |CON_ALT_SAVE+4
                STA    |CON_VT_STATE+VT_CUR_ROW
                LDA    |CON_ALT_SAVE+6
                STA    |CON_VT_STATE+VT_CUR_COL
                SEP     #$20
                LDA    |CON_ALT_SAVE+8
                STA    |CON_VT_STATE+VT_FOLLOW
                LDA    |CON_ALT_SAVE+9
                STA    |CON_VT_STATE+VT_FG
                LDA    |CON_ALT_SAVE+10
                STA    |CON_VT_STATE+VT_BG
                LDA    |CON_ALT_SAVE+11
                STA    |CON_VT_STATE+VT_G0_CHARSET
                LDA    |CON_ALT_SAVE+12
                STA    |CON_VT_STATE+VT_G1_CHARSET
                LDA    |CON_ALT_SAVE+13
                STA    |CON_VT_STATE+VT_GL
                REP     #$20
                ; (Bank-$04 PreExp variants for all 16 fg/bg combos are
                ;  pre-built at boot; no rebuild needed across alt-screen
                ;  switches — the renderer just selects a different variant.)
                JMP     Con_RenderAll

;==============================================================================
; END console_altscreen.s
;==============================================================================

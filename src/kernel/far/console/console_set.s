;==============================================================================
; console_set.s - PreExp font cache rebuild.
;
; Public:
;   Con_RebuildFontCache - regenerate CON_PREEXP + all 16 regular and 16 bold
;                          PreExpFont variants in bank $04 from the current
;                          CurrentFontPtr and Font_DEC_Graphics.
;
; Runtime swap (Con_LoadFontFromFile, Con_RevertToDefault) lives in
; console_font_loader.s and calls Con_RebuildFontCache when done.
;==============================================================================

;------------------------------------------------------------------------------
; Con_RebuildFontCache - rebuild all PreExpFont variants from CurrentFontPtr.
; Preserves caller's MX via PHP/PLP.  Internally MX %00.
;------------------------------------------------------------------------------
Con_RebuildFontCache
                PHP
                SEP     #$20
                ; The pre-build loops sweep _conFg/_conBg across 0..3 to
                ; build every (fg,bg) variant and leave them at 3,3 on
                ; exit; they also stomp the _conScratch* DP slots, so
                ; stash the caller's colors on the stack — not in DP —
                ; before invoking them.
                LDA    |CON_VT_STATE+VT_FG
                PHA
                LDA    |CON_VT_STATE+VT_BG
                PHA
                REP     #$30
                JSR     _Con_BuildAllPreExpFonts
                JSR     _Con_BuildBoldPreExpFonts
                SEP     #$20
                PLA
                STA    |CON_VT_STATE+VT_BG
                PLA
                STA    |CON_VT_STATE+VT_FG
@crfc_done      PLP
                RTS

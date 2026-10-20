;==============================================================================
; console_backend.s - a second place for the pixels to come from.
;
; The VT102 layer works on the cell ring and touches pixels at five sites:
; Con_RenderRow, _Con_RenderCell, Con_Clear, Con_ScrollRegionUp and
; Con_ScrollRegionDown.  Each site tests _conBackendOn and, when a module has
; registered its renderer, calls it through a JSL whose operand Con_SetBackend
; wrote; otherwise the SHR renderer runs as it always has.  A same-bank long
; call is not allowed (tools/check_selfbank_jsl.py), which is why the SHR
; routines are reached by JMP and the module's by a patched JSL rather than
; both through one vector.
;
; The module's routines are entered with DBR = this bank and MX %00, get what
; they need in registers so they never read the VT state, and RTL.  The table
; a module registers is five 3-byte routine addresses:
;
;   +0   RenderRow    A = viewport row, X = ring row, Y = VT_TOP_ROW
;   +3   RenderCell   A = viewport row, X = column,   Y = ring row
;   +6   Clear        Y = VT_TOP_ROW
;   +9   ScrollUp     A = top, X = bottom, Y = VT_TOP_ROW, already advanced
;   +12  ScrollDown   A = top, X = bottom, Y = VT_TOP_ROW
;
; The cells a module renders hold ANSI colour indexes (console_vtcolor.s), so
; its colours are its own: the SHR palette is the SHR's.
;
; A module reaches Con_SetBackend through SYS_KCALL service KSVC_CONBACKEND
; (include/modules.s), which the core forwards through far slot
; KFAR_CON_SETBACKEND.
;==============================================================================

                MX      %00

;------------------------------------------------------------------------------
; Con_SetBackend - A = table offset, Y = table bank.  DBR = this bank.
;
; Writes the five JSL operands and marks VC_CARD as the console the module
; displays.  Clobbers A, X, Y, _libcTmp2.
;------------------------------------------------------------------------------
Con_SetBackend  MX      %00
                STA     _libcTmp2
                SEP     #$20
                TYA
                STA     _libcTmp2+2
                REP     #$20
                ; The five operands: entry i at table+3i goes to the site named
                ; by _Con_HkSites[i], lo/hi as a word, bank as a byte.
                LDY     #0
@sb_site        PHY
                TYA
                ; site index = Y/3: Y runs 0,3,6,9,12 and the site table is
                ; indexed by word, so the site word is at (Y/3)*2.
                LDX     #0
@sb_div         CMP     #3
                BCC     @sb_haveIdx
                SBC     #3                      ; C is set
                INX
                INX
                BRA     @sb_div
@sb_haveIdx     LDA     _Con_HkSites,X
                TAX                             ; X = operand address in this bank
                PLY
                LDA     [_libcTmp2],Y           ; routine lo, hi
                STA     |$0000,X
                INY
                INY
                LDA     [_libcTmp2],Y           ; routine bank in the low byte
                SEP     #$20
                STA     |$0002,X
                REP     #$20
                INY
                CPY     #15
                BCC     @sb_site
                ; The card displays VC_CARD.  Con_LoadVCState turns the render
                ; sites toward the module whenever that console's state is
                ; live, which a write bracket makes it; the SHR keeps showing
                ; its own console, untouched.  The core's registration arm
                ; repaints VC_CARD's ring onto the card if the console already
                ; holds a session.
                SEP     #$20
                MX      %10
                LDA     #$80
                STA    |_conVcDisplay+VC_CARD
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; The five operand addresses, in the table's order.
;------------------------------------------------------------------------------
_Con_HkSites    DA      _Con_HkRenderRow+1
                DA      _Con_HkRenderCell+1
                DA      _Con_HkClear+1
                DA      _Con_HkScrollUp+1
                DA      _Con_HkScrollDown+1

;==============================================================================
; END console_backend.s
;==============================================================================

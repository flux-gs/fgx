                MX      %00                 ; reset Merlin mode tracking
;==============================================================================
; console_vtcolor.s - SGR state -> the current cell colours and attributes.
;
; _Vt_ApplySgr turns CON_VT_STATE's SgrState into VT_FG / VT_BG, which
; Con_PutChar and the erase and scroll fills stamp into CON_FGBUF /
; CON_BGBUF, and _Vt_ApplyFlags folds the flags into VT_ATTR.
;
; THE CELLS HOLD THE ANSI COLOUR INDEX, 0..15 in ECMA-48 order (black red
; green yellow blue magenta cyan white, +8 bright), and each display maps it
; to what it can show when it renders: the SHR 640 renderer through
; _Con_FgSlot / _Con_BgSlot below, the Second Sight card as the VGA
; attribute bg<<4|fg.  A cell never holds "default": SGR 0/39/49 resolve to
; the console's default pair, VT_DEF_COLOR, here.
;
; Entry/exit: M=0.  Called from _Vt_Handle_SGR, _Vt_Handle_RSB and
; _Vt_Handle_RIS in console_vthandler.s.
;==============================================================================

;------------------------------------------------------------------------------
; _Vt_ApplyFlags - read VT_SGR_FLAGS (bit 0=bold, 1=reverse, 2=underline)
; and fold into _conAttr bits 4 (B), 5 (I), 6 (U). Preserves fg/bg/G bits.
; Bit 3 (blink) is not an attribute: _Vt_ApplySgr applies it to the colour.
; Entry/exit: M=0 (same as _Vt_ApplySgr).
;------------------------------------------------------------------------------
_Vt_ApplyFlags
                SEP     #$20
                LDA    |CON_VT_STATE+VT_SGR_FLAGS
                STA     _conScratch0        ; flags in low 3 bits
                LDA    |CON_VT_STATE+VT_ATTR
                AND     #$8F                ; clear bits 4..6 (B/I/U); preserve G + fg/bg
                STA     _conScratch1
                ; bit 0 (bold) -> bit 4
                LDA     _conScratch0
                AND     #$01
                BEQ     @af_skipB
                LDA     _conScratch1
                ORA     #$10
                STA     _conScratch1
@af_skipB       LDA     _conScratch0
                AND     #$02                ; reverse
                BEQ     @af_skipR
                LDA     _conScratch1
                ORA     #$20                ; I bit
                STA     _conScratch1
@af_skipR       LDA     _conScratch0
                AND     #$04                ; underline
                BEQ     @af_skipU
                LDA     _conScratch1
                ORA     #$40                ; U bit
                STA     _conScratch1
@af_skipU       LDA     _conScratch1
                STA    |CON_VT_STATE+VT_ATTR
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Vt_ApplySgr - VT_SGR_FG / VT_SGR_BG / VT_SGR_FLAGS -> VT_FG, VT_BG, VT_ATTR.
;
; $FF in either colour is "default", the matching nibble of VT_DEF_COLOR.
; Blink (flag bit 3, $08) is the bright background -- iCE colour, sixteen
; backgrounds -- which is why the flag bit and the bright bit are the same
; value: the background is OR'd with the flags' bit 3.
;------------------------------------------------------------------------------
_Vt_ApplySgr
                SEP     #$20
                LDA    |CON_VT_STATE+VT_SGR_FG
                CMP     #$FF
                BNE     @as_fg
                LDA    |CON_VT_STATE+VT_DEF_COLOR
@as_fg          REP     #$20
                JSR     Con_SetFg               ; keeps the low nibble
                SEP     #$20
                LDA    |CON_VT_STATE+VT_SGR_BG
                CMP     #$FF
                BNE     @as_bg
                LDA    |CON_VT_STATE+VT_DEF_COLOR
                LSR
                LSR
                LSR
                LSR
@as_bg          PHA
                LDA    |CON_VT_STATE+VT_SGR_FLAGS
                AND     #$08                    ; blink: the bright background
                ORA     1,S
                STA     1,S
                PLA
                REP     #$20
                JSR     Con_SetBg               ; keeps the low nibble
                JMP     _Vt_ApplyFlags

;------------------------------------------------------------------------------
; _Con_FgSlot / _Con_BgSlot - ANSI colour index (0..15) -> the SHR 640
; renderer's palette slot.  640 mode has FOUR cell-addressable colours per
; row, so the sixteen fold onto them:
;   slot 0 = blue    (the IIgs system colour; the dark background)
;   slot 1 = grey    (black / white -- neutral, the default foreground)
;   slot 2 = red     (red / yellow / magenta -- warm)
;   slot 3 = green   (green / cyan -- cool)
; Bright colours fold with their base colour.  The two tables differ only
; for black: as a foreground it is the neutral grey, as a background the
; dark slot, so black on the IIgs screen is its blue and the default pair,
; 7 on 0, is grey on blue.  A cell whose two slots are equal renders
; invisible (the four-colour limit).  Read by the two colour decodes in
; console_render.s and by _Con_ClearShr.
;------------------------------------------------------------------------------
_Con_FgSlot
                DFB     1                   ; 0  black     -> grey (neutral)
                DFB     2                   ; 1  red       -> warm
                DFB     3                   ; 2  green     -> cool
                DFB     2                   ; 3  yellow    -> warm
                DFB     0                   ; 4  blue      -> blue slot
                DFB     2                   ; 5  magenta   -> warm
                DFB     3                   ; 6  cyan      -> cool
                DFB     1                   ; 7  white     -> grey (neutral)
                DFB     1                   ; 8  br.black
                DFB     2                   ; 9  br.red
                DFB     3                   ; 10 br.green
                DFB     2                   ; 11 br.yellow
                DFB     0                   ; 12 br.blue   -> blue slot
                DFB     2                   ; 13 br.magenta
                DFB     3                   ; 14 br.cyan
                DFB     1                   ; 15 br.white
_Con_BgSlot
                DFB     0                   ; 0  black     -> the dark slot
                DFB     2                   ; 1  red
                DFB     3                   ; 2  green
                DFB     2                   ; 3  yellow
                DFB     0                   ; 4  blue
                DFB     2                   ; 5  magenta
                DFB     3                   ; 6  cyan
                DFB     1                   ; 7  white
                DFB     0                   ; 8  br.black  -> the dark slot
                DFB     2                   ; 9  br.red
                DFB     3                   ; 10 br.green
                DFB     2                   ; 11 br.yellow
                DFB     0                   ; 12 br.blue
                DFB     2                   ; 13 br.magenta
                DFB     3                   ; 14 br.cyan
                DFB     1                   ; 15 br.white

;==============================================================================
; END console_vtcolor.s
;==============================================================================

;==============================================================================
; console_color.s - color/attribute API.
;
; Public:
;   Con_SetFg           A (low byte) = color 0..15. Stored in _conFg.
;   Con_SetBg           A (low byte) = color 0..15. Stored in _conBg.
;
; The renderer DOES consult both: Con_PutChar stamps _conFg/_conBg into
; CON_FGBUF/CON_BGBUF, and _Con_RenderCell composes the PreExpFont variant
; index from (bg<<2)|fg, so per-cell fg AND bg color both paint.
;==============================================================================

;------------------------------------------------------------------------------
; Con_SetFg - A (low byte) = palette index 0..15.
;
; Masks A to 0..15 and stores it in _conFg.  It does NOT touch _conAttr:
; colour left the attr byte when the per-cell CON_FGBUF/CON_BGBUF landed, so
; the actual per-cell write happens in Con_PutChar, which stamps _conFg into
; CON_FGBUF.  Existing cells keep their own colour (per-cell rendering).
;
; Cost: ~1 us (no repaint; existing text unaffected).
;
; 640 mode only uses the low 2 bits: those are the palette entries that appear
; in all four 640-mode sub-palette groups when the palette is mirrored.  320
; mode uses the full nibble.  (This header used to claim a hard 0..3 clamp and
; an _conAttr update, and pointed at a Con_SetPalette entry point that does not
; exist -- all three were stale.)
;------------------------------------------------------------------------------
Con_SetFg
                ; A (low byte) = palette index 0..15.  640 mode only uses
                ; the low 2 bits; 320 mode uses the full nibble.  Stored in
                ; _conFg; the actual per-cell write happens in Con_PutChar,
                ; which stamps _conFg into CON_FGBUF.
                AND     #$000F
                SEP     #$20
                STA    |CON_VT_STATE+VT_FG
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; Con_SetBg - A (low byte) = palette index 0..15 (640: low 2 bits = slot 0..3).
;
; Mirror of Con_SetFg for the background.  Stored in _conBg; Con_PutChar stamps
; it into CON_BGBUF, and _Con_RenderCell folds it into the (bg<<2)|fg variant
; index, so new cells paint with this bg color.  Existing cells keep their old
; bg (per-cell).  No repaint.
;------------------------------------------------------------------------------
Con_SetBg
                AND     #$000F
                SEP     #$20
                STA    |CON_VT_STATE+VT_BG
                REP     #$20
                RTS

;==============================================================================
; END console_color.s
;==============================================================================

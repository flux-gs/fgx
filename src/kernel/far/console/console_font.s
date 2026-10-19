;==============================================================================
; console_font.s - Console font data (DEC Special Graphics block only).
;
; The built-in default ASCII glyph block (Font_Default_ASCII) used to live here
; but was relegated to a disk resource (/lib/fonts/DEFAULT.FNT, loaded into the
; heap at Con_Init) for the kernel-bank reclaim -- see console_font_loader.s.
; What remains is the shared DEC Special Graphics block (Font_DEC_Graphics,
; 248 B), read directly by the pre-expand builder for box-drawing glyphs, so it
; stays compiled in.
;==============================================================================

;==============================================================================
; font_dec.s - DEC Special Graphics glyphs (31 glyphs, 248 bytes).
;
; Shared across all fonts for visual consistency of box-drawing characters.
; Source position $60..$7E of the DEC Special Graphics charset maps to glyph
; index (95 + (char - $60)) in the renderer's character index space.
;
; Bits 7..2 are the normal 6-pixel glyph; bits 1..0 are used for box-drawing
; line continuity into adjacent cells.
;==============================================================================

Font_DEC_Graphics
                ; ` ($60) diamond (glyph 95)
                DFB     $00,$10,$38,$7C,$38,$10,$00,$00
                ; a ($61) checkerboard stipple (glyph 96)
                DFB     $A8,$54,$A8,$54,$A8,$54,$A8,$54
                ; b ($62) HT horizontal-tab symbol (glyph 97)
                DFB     $40,$60,$70,$78,$70,$60,$40,$00
                ; c ($63) FF form-feed symbol (glyph 98)
                DFB     $10,$10,$10,$10,$10,$7C,$38,$10
                ; d ($64) CR carriage-return symbol (glyph 99)
                DFB     $00,$10,$30,$78,$30,$10,$00,$00
                ; e ($65) LF line-feed symbol (glyph 100)
                DFB     $10,$10,$10,$10,$78,$3C,$18,$10
                ; f ($66) degree (glyph 101)
                DFB     $18,$24,$24,$18,$00,$00,$00,$00
                ; g ($67) plus/minus (glyph 102)
                DFB     $00,$10,$7C,$10,$00,$7C,$00,$00
                ; h ($68) NL newline symbol (glyph 103)
                DFB     $00,$24,$34,$2C,$24,$00,$00,$00
                ; i ($69) VT vertical-tab symbol (glyph 104)
                DFB     $3C,$10,$10,$10,$10,$10,$10,$00
                ; j ($6A) BR corner (glyph 105)
                DFB     $10,$10,$10,$F0,$00,$00,$00,$00
                ; k ($6B) TR corner (glyph 106)
                DFB     $00,$00,$00,$F0,$10,$10,$10,$10
                ; l ($6C) TL corner (glyph 107)
                DFB     $00,$00,$00,$1F,$10,$10,$10,$10
                ; m ($6D) BL corner (glyph 108)
                DFB     $10,$10,$10,$1F,$00,$00,$00,$00
                ; n ($6E) cross (glyph 109)
                DFB     $10,$10,$10,$FF,$10,$10,$10,$10
                ; o ($6F) scan line 1 - top (glyph 110)
                DFB     $FF,$00,$00,$00,$00,$00,$00,$00
                ; p ($70) scan line 3 (glyph 111)
                DFB     $00,$00,$FF,$00,$00,$00,$00,$00
                ; q ($71) horizontal line / scan line 5 (glyph 112)
                DFB     $00,$00,$00,$FF,$00,$00,$00,$00
                ; r ($72) scan line 7 (glyph 113)
                DFB     $00,$00,$00,$00,$00,$FF,$00,$00
                ; s ($73) scan line 9 - bottom (glyph 114)
                DFB     $00,$00,$00,$00,$00,$00,$00,$FF
                ; t ($74) left tee (glyph 115)
                DFB     $10,$10,$10,$1F,$10,$10,$10,$10
                ; u ($75) right tee (glyph 116)
                DFB     $10,$10,$10,$F0,$10,$10,$10,$10
                ; v ($76) bottom tee (glyph 117)
                DFB     $10,$10,$10,$FF,$00,$00,$00,$00
                ; w ($77) top tee (glyph 118)
                DFB     $00,$00,$00,$FF,$10,$10,$10,$10
                ; x ($78) vertical line (glyph 119)
                DFB     $10,$10,$10,$10,$10,$10,$10,$10
                ; y ($79) less-or-equal (glyph 120)
                DFB     $00,$04,$10,$40,$10,$04,$00,$7C
                ; z ($7A) greater-or-equal (glyph 121)
                DFB     $00,$40,$10,$04,$10,$40,$00,$7C
                ; { ($7B) pi (glyph 122)
                DFB     $00,$7C,$14,$14,$14,$14,$00,$00
                ; | ($7C) not-equal (glyph 123)
                DFB     $00,$04,$7C,$18,$30,$7C,$40,$00
                ; } ($7D) UK pound (glyph 124)
                DFB     $0C,$10,$10,$38,$10,$10,$3C,$00
                ; ~ ($7E) bullet (glyph 125)
                DFB     $00,$00,$00,$18,$18,$00,$00,$00

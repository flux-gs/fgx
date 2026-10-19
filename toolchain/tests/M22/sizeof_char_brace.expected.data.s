;---------------------------------------
; fcc 0.0 — data segment for sizeof_char_brace.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
doopt           DFB     $FF
                DFB     $FD
                DFB     $25
                DFB     $63
                DFB     $00
two             DFB     $01
                DFB     $02
nums            DFB     $01
                DFB     $02
                DFB     $03
                FGX2_RELOC_COUNT 1

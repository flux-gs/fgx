;---------------------------------------
; fcc 0.0 — data segment for dpband.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
env             DS      48
s1              DFB     $61
                DFB     $62
                DFB     $63
                DFB     $64
                DFB     $65
                DFB     $66
                DFB     $67
                DFB     $68
                DFB     $00
s2              DFB     $41
                DFB     $42
                DFB     $43
                DFB     $44
                DFB     $45
                DFB     $46
                DFB     $47
                DFB     $48
                DFB     $00
calls           DS      2
                FGX2_RELOC_COUNT 1

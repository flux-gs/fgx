;---------------------------------------
; fcc 0.0 — data segment for parensubidx.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
a               DFB     $58
                DFB     $79
                DFB     $00
b               DFB     $51
                DFB     $7A
                DFB     $00
row             DS      8
                FGX2_RELOC_COUNT 1

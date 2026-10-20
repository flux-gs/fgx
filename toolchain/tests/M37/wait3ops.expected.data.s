;---------------------------------------
; fcc 0.0 — data segment for wait3ops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
nm              DFB     $2F
                DFB     $62
                DFB     $69
                DFB     $6E
                DFB     $2F
                DFB     $74
                DFB     $72
                DFB     $75
                DFB     $65
                DFB     $00
argv_tab        DS      4
                FGX2_RELOC_COUNT 1

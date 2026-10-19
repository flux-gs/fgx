;---------------------------------------
; fcc 0.0 — data segment for spawnops.c
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
argv_tab        DS      8

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _spawnops_S0
_spawnops_S0             HEX     2F,62,69,6E,2F,4E,4F,50,45,42,49,4E,00
                FGX2_RELOC_COUNT 2

;---------------------------------------
; fcc 0.0 — data segment for dirchurn.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
nbuf            DS      16

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _dirchurn_S0
_dirchurn_S0             HEX     6E,61,6D,65,25,30,32,64,00
                FGX2_EXPORT _dirchurn_S1
_dirchurn_S1             HEX     2F,62,69,6E,00
                FGX2_RELOC_COUNT 3

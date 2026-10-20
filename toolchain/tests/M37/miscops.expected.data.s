;---------------------------------------
; fcc 0.0 — data segment for miscops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _miscops_S0
_miscops_S0             HEX     20,2D,34,32,00
                FGX2_EXPORT _miscops_S1
_miscops_S1             HEX     31,30,30,30,30,30,00
                FGX2_EXPORT _miscops_S2
_miscops_S2             HEX     4E,4F,50,45,56,41,52,00
                FGX2_RELOC_COUNT 4

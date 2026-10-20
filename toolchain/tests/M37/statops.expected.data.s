;---------------------------------------
; fcc 0.0 — data segment for statops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _statops_S0
_statops_S0             HEX     2F,62,69,6E,2F,74,72,75,65,00
                FGX2_EXPORT _statops_S1
_statops_S1             HEX     2F,6E,6F,73,75,63,68,66,69,6C,65,00
                FGX2_RELOC_COUNT 3

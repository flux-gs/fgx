;---------------------------------------
; fcc 0.0 — data segment for tcops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _tcops_S0
_tcops_S0             HEX     76,74,31,30,30,00
                FGX2_EXPORT _tcops_S1
_tcops_S1             HEX     63,6F,00
                FGX2_EXPORT _tcops_S2
_tcops_S2             HEX     63,6D,00
                FGX2_EXPORT _tcops_S3
_tcops_S3             HEX     7A,7A,00
                FGX2_RELOC_COUNT 5

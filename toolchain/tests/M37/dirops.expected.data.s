;---------------------------------------
; fcc 0.0 — data segment for dirops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _dirops_S0
_dirops_S0             HEX     2F,62,69,6E,00
                FGX2_EXPORT _dirops_S1
_dirops_S1             HEX     2F,65,74,63,00
                FGX2_EXPORT _dirops_S2
_dirops_S2             HEX     74,72,75,65,00
                FGX2_EXPORT _dirops_S3
_dirops_S3             HEX     73,68,00
                FGX2_RELOC_COUNT 5

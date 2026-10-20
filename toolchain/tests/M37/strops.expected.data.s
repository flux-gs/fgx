;---------------------------------------
; fcc 0.0 — data segment for strops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
g1              DS      24
g2              DS      24

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _strops_S0
_strops_S0             HEX     68,65,6C,6C,6F,00
                FGX2_EXPORT _strops_S1
_strops_S1             HEX     68,65,6C,00
                FGX2_EXPORT _strops_S2
_strops_S2             HEX     6C,6F,00
                FGX2_EXPORT _strops_S3
_strops_S3             HEX     68,65,6C,70,00
                FGX2_RELOC_COUNT 5

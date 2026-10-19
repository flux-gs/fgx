;---------------------------------------
; fcc 0.0 — data segment for pf_long.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
b1              DS      16
b2              DS      16
b3              DS      16
b4              DS      16
b5              DS      16
b6              DS      16

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _pf_long_S0
_pf_long_S0             HEX     25,6C,64,00
                FGX2_EXPORT _pf_long_S1
_pf_long_S1             HEX     25,6C,78,00
                FGX2_EXPORT _pf_long_S2
_pf_long_S2             HEX     25,6C,75,00
                FGX2_EXPORT _pf_long_S3
_pf_long_S3             HEX     31,30,30,30,30,30,00
                FGX2_EXPORT _pf_long_S4
_pf_long_S4             HEX     2D,31,30,30,30,30,30,00
                FGX2_EXPORT _pf_long_S5
_pf_long_S5             HEX     31,32,33,34,35,36,37,38,00
                FGX2_EXPORT _pf_long_S6
_pf_long_S6             HEX     34,32,39,34,39,36,37,32,39,35,00
                FGX2_EXPORT _pf_long_S7
_pf_long_S7             HEX     36,35,35,33,35,00
                FGX2_EXPORT _pf_long_S8
_pf_long_S8             HEX     36,35,35,33,36,00
                FGX2_RELOC_COUNT 10

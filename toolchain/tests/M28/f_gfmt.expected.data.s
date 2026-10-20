;---------------------------------------
; fcc 0.0 — data segment for f_gfmt.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      32

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _f_gfmt_S0
_f_gfmt_S0             HEX     25,67,00
                FGX2_EXPORT _f_gfmt_S1
_f_gfmt_S1             HEX     33,2E,35,00
                FGX2_EXPORT _f_gfmt_S2
_f_gfmt_S2             HEX     31,30,30,30,30,30,00
                FGX2_EXPORT _f_gfmt_S3
_f_gfmt_S3             HEX     31,65,2B,30,36,00
                FGX2_EXPORT _f_gfmt_S4
_f_gfmt_S4             HEX     30,2E,30,30,30,31,00
                FGX2_EXPORT _f_gfmt_S5
_f_gfmt_S5             HEX     31,65,2D,30,35,00
                FGX2_EXPORT _f_gfmt_S6
_f_gfmt_S6             HEX     30,00
                FGX2_EXPORT _f_gfmt_S7
_f_gfmt_S7             HEX     33,2E,31,34,31,35,39,00
                FGX2_EXPORT _f_gfmt_S8
_f_gfmt_S8             HEX     25,2E,33,67,00
                FGX2_EXPORT _f_gfmt_S9
_f_gfmt_S9             HEX     33,2E,31,34,00
                FGX2_EXPORT _f_gfmt_S10
_f_gfmt_S10            HEX     30,2E,30,30,30,31,32,33,00
                FGX2_EXPORT _f_gfmt_S11
_f_gfmt_S11            HEX     2D,32,2E,35,00
                FGX2_RELOC_COUNT 13

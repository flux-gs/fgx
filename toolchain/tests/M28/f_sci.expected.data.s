;---------------------------------------
; fcc 0.0 — data segment for f_sci.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      32

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _f_sci_S0
_f_sci_S0             HEX     25,65,00
                FGX2_EXPORT _f_sci_S1
_f_sci_S1             HEX     30,2E,30,30,30,30,30,30,65,2B,30,30,00
                FGX2_EXPORT _f_sci_S2
_f_sci_S2             HEX     32,2E,30,30,30,30,30,30,65,2B,30,30,00
                FGX2_EXPORT _f_sci_S3
_f_sci_S3             HEX     35,2E,30,30,30,30,30,30,65,2D,30,31,00
                FGX2_EXPORT _f_sci_S4
_f_sci_S4             HEX     31,2E,30,30,30,30,30,30,65,2B,30,32,00
                FGX2_EXPORT _f_sci_S5
_f_sci_S5             HEX     25,2E,31,65,00
                FGX2_EXPORT _f_sci_S6
_f_sci_S6             HEX     32,2E,35,65,2D,30,31,00
                FGX2_RELOC_COUNT 8

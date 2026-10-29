;---------------------------------------
; fcc 0.0 — data segment for pfdigits.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
b               DS      64

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _pfdigits_S0
_pfdigits_S0             HEX     25,64,20,25,64,20,25,75,20,25,64,00
                FGX2_EXPORT _pfdigits_S1
_pfdigits_S1             HEX     30,20,39,20,36,35,35,33,35,20,2D,33,32,37,36,38,00
                FGX2_EXPORT _pfdigits_S2
_pfdigits_S2             HEX     25,6C,64,20,25,6C,75,20,25,6C,64,00
                FGX2_EXPORT _pfdigits_S3
_pfdigits_S3             HEX     36,35,35,33,35,20,36,35,35,33,36,20,36,35,35,33,35,39,00
                FGX2_EXPORT _pfdigits_S4
_pfdigits_S4             HEX     25,6C,75,20,25,6C,64,00
                FGX2_EXPORT _pfdigits_S5
_pfdigits_S5             HEX     34,32,39,34,39,36,37,32,39,35,20,2D,32,31,34,37,34,38,33,36,34,38,00
                FGX2_EXPORT _pfdigits_S6
_pfdigits_S6             HEX     25,6F,20,25,23,6F,20,25,6C,6F,20,25,6F,00
                FGX2_EXPORT _pfdigits_S7
_pfdigits_S7             HEX     31,30,20,30,31,30,20,32,30,30,30,30,30,20,30,00
                FGX2_EXPORT _pfdigits_S8
_pfdigits_S8             HEX     25,78,20,25,58,20,25,23,6C,78,20,25,6C,78,00
                FGX2_EXPORT _pfdigits_S9
_pfdigits_S9             HEX     62,65,65,66,20,42,45,45,46,20,30,78,31,32,33,34,35,20,66,66,66,66,66,66,66,66,00
                FGX2_EXPORT _pfdigits_S10
_pfdigits_S10            HEX     25,35,64,7C,25,2D,36,6C,75,7C,25,2E,33,64,7C,25,2E,30,64,00
                FGX2_EXPORT _pfdigits_S11
_pfdigits_S11            HEX     20,20,20,34,32,7C,31,30,30,30,30,30,7C,30,30,37,7C,00
                FGX2_EXPORT _pfdigits_S12
_pfdigits_S12            HEX     25,63,25,73,25,64,00
                FGX2_EXPORT _pfdigits_S13
_pfdigits_S13            HEX     79,00
                FGX2_EXPORT _pfdigits_S14
_pfdigits_S14            HEX     78,79,31,30,00
                FGX2_RELOC_COUNT 16

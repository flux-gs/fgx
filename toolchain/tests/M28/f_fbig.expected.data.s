;---------------------------------------
; fcc 0.0 — data segment for f_fbig.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      48

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _f_fbig_S0
_f_fbig_S0             HEX     25,2E,31,66,00
                FGX2_EXPORT _f_fbig_S1
_f_fbig_S1             HEX     32,30,30,30,30,30,30,30,30,30,2E,30,00
                FGX2_EXPORT _f_fbig_S2
_f_fbig_S2             HEX     33,30,30,30,30,30,30,30,30,30,2E,30,00
                FGX2_EXPORT _f_fbig_S3
_f_fbig_S3             HEX     34,32,39,34,39,36,37,30,34,30,2E,30,00
                FGX2_RELOC_COUNT 5

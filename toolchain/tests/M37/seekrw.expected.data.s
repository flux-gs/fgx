;---------------------------------------
; fcc 0.0 — data segment for seekrw.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      64

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _seekrw_S0
_seekrw_S0             HEX     2F,74,6D,70,2F,73,72,77,00
                FGX2_EXPORT _seekrw_S1
_seekrw_S1             HEX     58,59,5A,00
                FGX2_EXPORT _seekrw_S2
_seekrw_S2             HEX     30,31,32,33,34,35,36,37,00
                FGX2_EXPORT _seekrw_S3
_seekrw_S3             HEX     38,39,61,62,63,64,65,66,00
                FGX2_EXPORT _seekrw_S4
_seekrw_S4             HEX     49,4A,4B,4C,4D,4E,4F,50,00
                FGX2_RELOC_COUNT 6

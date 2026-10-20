;---------------------------------------
; fcc 0.0 — data segment for strsub.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
idx             DS      2

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _strsub_S0
_strsub_S0             HEX     30,34,32,36,31,35,33,37,00
                FGX2_EXPORT _strsub_S1
_strsub_S1             HEX     41,42,43,44,00
                FGX2_EXPORT _strsub_S2
_strsub_S2             HEX     77,78,79,7A,00
                FGX2_RELOC_COUNT 4

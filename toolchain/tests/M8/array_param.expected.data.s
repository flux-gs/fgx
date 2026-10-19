;---------------------------------------
; fcc 0.0 — data segment for array_param.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
arr             DS      4
strs            DS      8

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _array_param_S0
_array_param_S0             HEX     37,00
                FGX2_EXPORT _array_param_S1
_array_param_S1             HEX     33,00
                FGX2_RELOC_COUNT 3

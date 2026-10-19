;---------------------------------------
; fcc 0.0 — data segment for ptr_typedef.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
ga              DS      4
gb              DS      4
garr            DS      12

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _ptr_typedef_S0
_ptr_typedef_S0             HEX     41,42,00
                FGX2_EXPORT _ptr_typedef_S1
_ptr_typedef_S1             HEX     5A,00
                FGX2_RELOC_COUNT 3

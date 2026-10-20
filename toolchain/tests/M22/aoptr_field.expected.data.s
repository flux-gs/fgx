;---------------------------------------
; fcc 0.0 — data segment for aoptr_field.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
ga              DS      4
gb              DS      4

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _aoptr_field_S0
_aoptr_field_S0             HEX     41,41,00
                FGX2_EXPORT _aoptr_field_S1
_aoptr_field_S1             HEX     42,42,00
                FGX2_RELOC_COUNT 3

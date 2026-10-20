;---------------------------------------
; fcc 0.0 — data segment for uderef.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
cell            DS      2
buf             DS      16

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _uderef_S0
_uderef_S0             HEX     25,75,00
                FGX2_RELOC_COUNT 2

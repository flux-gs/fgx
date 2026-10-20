;---------------------------------------
; fcc 0.0 — data segment for freadn.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
rec             DS      36
in              DS      36

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _freadn_S0
_freadn_S0             HEX     2F,74,6D,70,2F,66,72,6E,00
                FGX2_EXPORT _freadn_S1
_freadn_S1             HEX     77,00
                FGX2_EXPORT _freadn_S2
_freadn_S2             HEX     72,00
                FGX2_RELOC_COUNT 4

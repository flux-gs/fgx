;---------------------------------------
; fcc 0.0 — data segment for strescapes.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _strescapes_S0
_strescapes_S0             HEX     1B,5B,32,4A,1B,5B,48,00
                FGX2_EXPORT _strescapes_S1
_strescapes_S1             HEX     1B,5B,41,00
                FGX2_EXPORT _strescapes_S2
_strescapes_S2             HEX     07,1B,DC,00
                FGX2_RELOC_COUNT 4

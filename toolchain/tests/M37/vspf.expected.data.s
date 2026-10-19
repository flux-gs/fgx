;---------------------------------------
; fcc 0.0 — data segment for vspf.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
gbuf            DS      40
ov              DS      8

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _vspf_S0
_vspf_S0             HEX     25,73,2D,25,64,00
                FGX2_EXPORT _vspf_S1
_vspf_S1             HEX     61,62,00
                FGX2_EXPORT _vspf_S2
_vspf_S2             HEX     61,62,2D,37,00
                FGX2_RELOC_COUNT 4

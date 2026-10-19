;---------------------------------------
; fcc 0.0 — data segment for sprintf_global.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      12

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _sprintf_global_S0
_sprintf_global_S0             HEX     25,64,25,63,00
                FGX2_RELOC_COUNT 2

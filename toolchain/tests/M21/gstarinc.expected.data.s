;---------------------------------------
; fcc 0.0 — data segment for gstarinc.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
g_msg           FGX2_LONG_PTR _Sg;_gstarinc_S0;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _gstarinc_S0
_gstarinc_S0             HEX     2A,51,00
                FGX2_RELOC_COUNT 3

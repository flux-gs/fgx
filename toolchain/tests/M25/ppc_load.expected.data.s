;---------------------------------------
; fcc 0.0 — data segment for ppc_load.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
g               FGX2_LONG_PTR _Sg;_ppc_load_S0;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _ppc_load_S0
_ppc_load_S0             HEX     2A,00
                FGX2_RELOC_COUNT 3

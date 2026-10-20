;---------------------------------------
; fcc 0.0 — data segment for ppc_param.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
g               FGX2_LONG_PTR _Sg;_ppc_param_S0;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _ppc_param_S0
_ppc_param_S0             HEX     2A,00
                FGX2_RELOC_COUNT 3

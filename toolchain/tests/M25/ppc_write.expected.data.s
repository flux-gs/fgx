;---------------------------------------
; fcc 0.0 — data segment for ppc_write.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
a               FGX2_LONG_PTR _Sg;_ppc_write_S0;0
b               FGX2_LONG_PTR _Sg;_ppc_write_S1;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _ppc_write_S0
_ppc_write_S0             HEX     41,00
                FGX2_EXPORT _ppc_write_S1
_ppc_write_S1             HEX     2A,00
                FGX2_RELOC_COUNT 5

;---------------------------------------
; fcc 0.0 — data segment for fseek_ftell.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _fseek_ftell_S0
_fseek_ftell_S0             HEX     2F,74,65,73,74,64,61,74,61,2F,66,74,65,6C,6C,00
                FGX2_EXPORT _fseek_ftell_S1
_fseek_ftell_S1             HEX     72,00
                FGX2_RELOC_COUNT 3

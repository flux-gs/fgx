;---------------------------------------
; fcc 0.0 — data segment for sys_inc.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _sys_inc_S0
_sys_inc_S0             HEX     73,79,73,69,6E,63,20,6F,6B,0A,00
                FGX2_EXPORT _sys_inc_S1
_sys_inc_S1             HEX     68,65,6C,6C,6F,00
                FGX2_EXPORT _sys_inc_S2
_sys_inc_S2             HEX     77,6F,72,6C,64,00
                FGX2_RELOC_COUNT 4

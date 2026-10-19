;---------------------------------------
; fcc 0.0 — data segment for sysops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _sysops_S0
_sysops_S0             HEX     2F,62,69,6E,2F,74,72,75,65,00
                FGX2_EXPORT _sysops_S1
_sysops_S1             HEX     2F,62,69,6E,2F,66,61,6C,73,65,00
                FGX2_RELOC_COUNT 3

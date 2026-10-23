;---------------------------------------
; fcc 0.0 — data segment for popen.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _popen_S0
_popen_S0             HEX     65,63,68,6F,20,68,69,00
                FGX2_EXPORT _popen_S1
_popen_S1             HEX     72,00
                FGX2_EXPORT _popen_S2
_popen_S2             HEX     63,61,74,20,3E,2F,64,65,76,2F,6E,75,6C,6C,00
                FGX2_EXPORT _popen_S3
_popen_S3             HEX     77,00
                FGX2_EXPORT _popen_S4
_popen_S4             HEX     64,69,73,63,61,72,64,65,64,0A,00
                FGX2_EXPORT _popen_S5
_popen_S5             HEX     65,78,69,74,20,33,00
                FGX2_RELOC_COUNT 7

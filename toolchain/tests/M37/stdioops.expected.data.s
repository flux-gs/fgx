;---------------------------------------
; fcc 0.0 — data segment for stdioops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _stdioops_S0
_stdioops_S0             HEX     2F,74,6D,70,2F,73,69,6F,00
                FGX2_EXPORT _stdioops_S1
_stdioops_S1             HEX     77,00
                FGX2_EXPORT _stdioops_S2
_stdioops_S2             HEX     68,65,6C,6C,6F,0A,00
                FGX2_EXPORT _stdioops_S3
_stdioops_S3             HEX     72,00
                FGX2_EXPORT _stdioops_S4
_stdioops_S4             HEX     68,69,00
                FGX2_EXPORT _stdioops_S5
_stdioops_S5             HEX     71,00
                FGX2_RELOC_COUNT 7

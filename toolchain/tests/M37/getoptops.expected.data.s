;---------------------------------------
; fcc 0.0 — data segment for getoptops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
av              DS      32

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _getoptops_S0
_getoptops_S0             HEX     70,72,6F,67,00
                FGX2_EXPORT _getoptops_S1
_getoptops_S1             HEX     2D,6C,61,00
                FGX2_EXPORT _getoptops_S2
_getoptops_S2             HEX     2D,6F,00
                FGX2_EXPORT _getoptops_S3
_getoptops_S3             HEX     6F,75,74,2E,74,78,74,00
                FGX2_EXPORT _getoptops_S4
_getoptops_S4             HEX     2D,7A,66,61,74,74,61,63,68,00
                FGX2_EXPORT _getoptops_S5
_getoptops_S5             HEX     2D,2D,00
                FGX2_EXPORT _getoptops_S6
_getoptops_S6             HEX     2D,6C,00
                FGX2_EXPORT _getoptops_S7
_getoptops_S7             HEX     61,6C,6F,3A,66,3A,78,00
                FGX2_EXPORT _getoptops_S8
_getoptops_S8             HEX     61,74,74,61,63,68,00
                FGX2_RELOC_COUNT 10

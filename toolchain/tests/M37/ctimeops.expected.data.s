;---------------------------------------
; fcc 0.0 — data segment for ctimeops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
e0              DA      $0000
                DA      $0000
e1              DA      $B900
                DA      $6955
e2              DA      $C900
                DA      $65DF
e3              DA      $D097
                DA      $6A43

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _ctimeops_S0
_ctimeops_S0             HEX     54,5A,00
                FGX2_EXPORT _ctimeops_S1
_ctimeops_S1             HEX     47,4D,54,00
                FGX2_EXPORT _ctimeops_S2
_ctimeops_S2             HEX     54,68,75,20,4A,61,6E,20,20,31,20,30,30,3A,30,30,3A,30,30,20,31,39,37,30,0A,00
                FGX2_EXPORT _ctimeops_S3
_ctimeops_S3             HEX     54,68,75,20,4A,61,6E,20,20,31,20,30,30,3A,30,30,3A,30,30,20,32,30,32,36,0A,00
                FGX2_EXPORT _ctimeops_S4
_ctimeops_S4             HEX     54,68,75,20,46,65,62,20,32,39,20,30,30,3A,30,30,3A,30,30,20,32,30,32,34,0A,00
                FGX2_EXPORT _ctimeops_S5
_ctimeops_S5             HEX     54,75,65,20,4A,75,6E,20,33,30,20,31,34,3A,32,30,3A,30,37,20,32,30,32,36,0A,00
                FGX2_RELOC_COUNT 7

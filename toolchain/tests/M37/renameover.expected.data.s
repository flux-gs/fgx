;---------------------------------------
; fcc 0.0 — data segment for renameover.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _renameover_S0
_renameover_S0             HEX     2F,74,6D,70,2F,72,6F,76,73,72,63,00
                FGX2_EXPORT _renameover_S1
_renameover_S1             HEX     4E,45,57,00
                FGX2_EXPORT _renameover_S2
_renameover_S2             HEX     2F,74,6D,70,2F,72,6F,76,64,73,74,00
                FGX2_EXPORT _renameover_S3
_renameover_S3             HEX     6F,6C,64,6F,6C,64,00
                FGX2_EXPORT _renameover_S4
_renameover_S4             HEX     58,00
                FGX2_EXPORT _renameover_S5
_renameover_S5             HEX     2F,72,6F,76,64,73,74,32,00
                FGX2_RELOC_COUNT 7

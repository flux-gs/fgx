;---------------------------------------
; fcc 0.0 — data segment for bracescalar.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
gp              FGX2_LONG_PTR _Sg;_bracescalar_S0;0
gl              DA      $1170
                DA      $0001
gi              DA      $FFFD
f_sl_k          DA      $0005

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _bracescalar_S0
_bracescalar_S0             HEX     65,6A,65,63,74,00
                FGX2_EXPORT _bracescalar_S1
_bracescalar_S1             HEX     7A,00
                FGX2_RELOC_COUNT 4

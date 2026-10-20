;---------------------------------------
; fcc 0.0 — data segment for partial_sinit.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
tbl             FGX2_LONG_PTR _Sa;_partial_sinit_S0;0
                DA      $000A
                DA      $0003
                FGX2_LONG_PTR _Sa;_partial_sinit_S1;0
                DA      $0014
                DA      $0005
                DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000
                DA      $0000

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _partial_sinit_S0
_partial_sinit_S0             HEX     6D,61,70,00
                FGX2_EXPORT _partial_sinit_S1
_partial_sinit_S1             HEX     71,75,69,74,00
                FGX2_RELOC_COUNT 5

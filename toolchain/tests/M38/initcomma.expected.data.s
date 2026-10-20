;---------------------------------------
; fcc 0.0 — data segment for initcomma.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
_initcomma_elems FGX2_LONG_PTR _Sa;_initcomma_S0;0
                DA      $0000
                DA      $0001
                FGX2_LONG_PTR _Sa;_initcomma_S1;0
                DA      $0000
                DA      $0000
                FGX2_LONG_PTR _Sa;_initcomma_S2;0
                DA      $0000
                DA      $0000
                DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000
                DA      $0000
_initcomma_ints DA      $0001
                DA      $0002
                DA      $0003
_initcomma_strs FGX2_LONG_PTR _Sa;_initcomma_S3;0
                FGX2_LONG_PTR _Sa;_initcomma_S4;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _initcomma_S0
_initcomma_S0             HEX     72,6F,00
                FGX2_EXPORT _initcomma_S1
_initcomma_S1             HEX     6E,61,00
                FGX2_EXPORT _initcomma_S2
_initcomma_S2             HEX     61,75,74,6F,00
                FGX2_EXPORT _initcomma_S3
_initcomma_S3             HEX     61,00
                FGX2_EXPORT _initcomma_S4
_initcomma_S4             HEX     62,00
                FGX2_RELOC_COUNT 11

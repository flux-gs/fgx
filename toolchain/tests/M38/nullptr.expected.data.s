;---------------------------------------
; fcc 0.0 — data segment for nullptr.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
_nullptr_tab    FGX2_LONG_PTR _Sa;_nullptr_S0;0
                FGX2_LONG_PTR _Sa;_nullptr_S1;0
                DA      $0000
                DFB     $00
                DFB     $00
pick_sl_cached  DA      $0000
                DA      $0000

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _nullptr_S0
_nullptr_S0             HEX     61,61,00
                FGX2_EXPORT _nullptr_S1
_nullptr_S1             HEX     62,62,00
                FGX2_EXPORT _nullptr_S2
_nullptr_S2             HEX     7A,7A,00
                FGX2_RELOC_COUNT 6

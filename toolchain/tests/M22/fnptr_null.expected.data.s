;---------------------------------------
; fcc 0.0 — data segment for fnptr_null.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
tbl             FGX2_LONG_PTR _Sa;_fnptr_null_S0;0
                DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000
                DFB     $00
                DFB     $00
                FGX2_LONG_PTR _Sa;_fnptr_null_S1;0
                FGX2_LONG_PTR _Fa;add40;0
                DA      $0000
                DFB     $00
                DFB     $00

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _fnptr_null_S0
_fnptr_null_S0             HEX     61,00
                FGX2_EXPORT _fnptr_null_S1
_fnptr_null_S1             HEX     62,00
                FGX2_RELOC_COUNT 6

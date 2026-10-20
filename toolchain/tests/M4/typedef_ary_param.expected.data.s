;---------------------------------------
; fcc 0.0 — data segment for typedef_ary_param.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
tag             DFB     $63
                DFB     $64
                DFB     $00
table           FGX2_LONG_PTR _Sa;_typedef_ary_param_S0;0
                DA      $0002
                FGX2_LONG_PTR _Sa;_typedef_ary_param_S1;0
                DA      $0011
                DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _typedef_ary_param_S0
_typedef_ary_param_S0             HEX     63,64,00
                FGX2_EXPORT _typedef_ary_param_S1
_typedef_ary_param_S1             HEX     72,65,61,64,00
                FGX2_RELOC_COUNT 5

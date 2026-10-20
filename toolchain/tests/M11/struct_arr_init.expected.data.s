;---------------------------------------
; fcc 0.0 — data segment for struct_arr_init.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
items           FGX2_LONG_PTR _Sa;_struct_arr_init_S0;0
                DA      $000A
                FGX2_LONG_PTR _Sa;_struct_arr_init_S1;0
                DA      $000E
                FGX2_LONG_PTR _Sa;_struct_arr_init_S2;0
                DA      $0012

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _struct_arr_init_S0
_struct_arr_init_S0             HEX     61,6C,70,68,61,00
                FGX2_EXPORT _struct_arr_init_S1
_struct_arr_init_S1             HEX     61,6E,73,77,65,72,00
                FGX2_EXPORT _struct_arr_init_S2
_struct_arr_init_S2             HEX     67,61,6D,6D,61,00
                FGX2_RELOC_COUNT 7

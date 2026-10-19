;---------------------------------------
; fcc 0.0 — data segment for static_arr_init.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
main_sl_names   FGX2_LONG_PTR _Sa;_static_arr_init_S0;0
                FGX2_LONG_PTR _Sa;_static_arr_init_S1;0
                FGX2_LONG_PTR _Sa;_static_arr_init_S2;0
main_sl_buf     DFB     $78
                DFB     $79
                DFB     $7A
                DFB     $00
main_sl_nums    DA      $000A
                DA      $0014
                DA      $001E
                DA      $FFFF

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _static_arr_init_S0
_static_arr_init_S0             HEX     61,61,00
                FGX2_EXPORT _static_arr_init_S1
_static_arr_init_S1             HEX     62,62,00
                FGX2_EXPORT _static_arr_init_S2
_static_arr_init_S2             HEX     63,63,00
                FGX2_RELOC_COUNT 7

;---------------------------------------
; fcc 0.0 — data segment for charptr_arr_global.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT aa
aa              DFB     $41
                DFB     $42
                DFB     $00
                FGX2_EXPORT bb
bb              DFB     $43
                DFB     $44
                DFB     $00
tbl             LIBC_DATA_PTR _Ga;aa
                LIBC_DATA_PTR _Ga;bb
                FGX2_LONG_PTR _Sa;_charptr_arr_global_S0;0
                DA      $0000
                DFB     $00
                DFB     $00
scount_sl_pv    LIBC_DATA_PTR _Ga;aa
                LIBC_DATA_PTR _Ga;bb
                DA      $0000
                DFB     $00
                DFB     $00

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _charptr_arr_global_S0
_charptr_arr_global_S0             HEX     45,46,00
                FGX2_RELOC_COUNT 9

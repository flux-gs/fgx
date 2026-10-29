;---------------------------------------
; fcc 0.0 — data segment for ptr_held.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT c3
c3              DA      $0003
                DA      $0000
                DFB     $00
                DFB     $00
                FGX2_LONG_PTR _Sa;_ptr_held_S0;0
                FGX2_EXPORT c2
c2              DA      $0002
                LIBC_DATA_PTR _Ga;c3
                FGX2_LONG_PTR _Sa;_ptr_held_S1;0
c1              DA      $0001
                LIBC_DATA_PTR _Ga;c2
                FGX2_LONG_PTR _Sa;_ptr_held_S2;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _ptr_held_S0
_ptr_held_S0             HEX     74,68,72,65,65,00
                FGX2_EXPORT _ptr_held_S1
_ptr_held_S1             HEX     74,77,6F,00
                FGX2_EXPORT _ptr_held_S2
_ptr_held_S2             HEX     6F,6E,65,00
                FGX2_RELOC_COUNT 11

;---------------------------------------
; fcc 0.0 — data segment for cfield_gaddr.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT gbuf
gbuf            DS      4
opts            FGX2_LONG_PTR _Sa;_cfield_gaddr_S0;0
                DFB     $01
                DFB     $00
                LIBC_DATA_PTR _Ga;gbuf
                FGX2_LONG_PTR _Sa;_cfield_gaddr_S1;0
                DFB     $00
                DFB     $00
                DA      $0000
                DFB     $00
                DFB     $00

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _cfield_gaddr_S0
_cfield_gaddr_S0             HEX     61,69,00
                FGX2_EXPORT _cfield_gaddr_S1
_cfield_gaddr_S1             HEX     73,65,6E,74,69,6E,65,6C,00
                FGX2_RELOC_COUNT 7

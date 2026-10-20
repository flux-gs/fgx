;---------------------------------------
; fcc 0.0 — data segment for init_constcast.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
cols            DFB     $50
                DFB     $20
                DFB     $FF
flags           DA      $0010
                DA      $0015
keys            DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000
                DFB     $00
                DFB     $00
                DA      $FFFF
                DA      $0000
                DFB     $00
                DFB     $00
                FGX2_LONG_PTR _Sa;_init_constcast_S0;0
                DA      $0005

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _init_constcast_S0
_init_constcast_S0             HEX     78,00
                FGX2_RELOC_COUNT 3

;---------------------------------------
; fcc 0.0 — data segment for static_local_wide_init.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
f_sl_d          DA      $0000
                DA      $0000
                DA      $0000
                DA      $3FF8
                DA      $0000
                DA      $0000
                DA      $0000
                DA      $4004
                DA      $0000
                DA      $0000
                DA      $0000
                DA      $4008
f_sl_fl         DA      $0000
                DA      $3F00
                DA      $0000
                DA      $3FC0
f_sl_l          DA      $86A0
                DA      $0001
                DA      $0007
                DA      $0000
f_sl_q          DA      $0005
                DA      $0000
                DA      $0000
                DA      $0000
                DA      $0006
                DA      $0000
                DA      $0000
                DA      $0000
                FGX2_RELOC_COUNT 1

;---------------------------------------
; fcc 0.0 — data segment for f_decl.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
g_pi            DA      $F5C3
                DA      $4048
g_two           DA      $0000
                DA      $4000
g_half          DA      $0000
                DA      $3F00
g_neg           DA      $0000
                DA      $BFC0
g_one           DA      $0000
                DA      $0000
                DA      $0000
                DA      $3FF0
g_arr           DS      12
                FGX2_RELOC_COUNT 1

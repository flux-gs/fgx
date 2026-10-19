;---------------------------------------
; fcc 0.0 — data segment for static_struct_ptr.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
gd              DS      4
get_sl_dp       DA      $0000
                DA      $0000
                FGX2_RELOC_COUNT 1

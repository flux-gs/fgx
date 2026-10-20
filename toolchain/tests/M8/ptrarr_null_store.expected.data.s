;---------------------------------------
; fcc 0.0 — data segment for ptrarr_null_store.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
g_static        DA      $0000
                DA      $0000
g_run           DS      4
vec             DS      12
vec_init        DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000
                DFB     $00
                DFB     $00
                DA      $0000
                DFB     $00
                DFB     $00
s0              DS      2
                FGX2_RELOC_COUNT 1
